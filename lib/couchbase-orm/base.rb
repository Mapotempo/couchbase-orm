# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

require 'active_model'
require 'active_record'
if ActiveModel::VERSION::MAJOR >= 6
  require 'active_record/database_configurations'
else
  require 'active_model/type'
end
require 'active_support/hash_with_indifferent_access'
require 'couchbase'
require 'couchbase-orm/extensions/string'
require 'couchbase-orm/error'
require 'couchbase-orm/views'
require 'couchbase-orm/n1ql'
require 'couchbase-orm/persistence'
require 'couchbase-orm/associations'
require 'couchbase-orm/types'
require 'couchbase-orm/relation'
require 'couchbase-orm/proxies/bucket_proxy'
require 'couchbase-orm/proxies/collection_proxy'
require 'couchbase-orm/utilities/join'
require 'couchbase-orm/utilities/enum'
require 'couchbase-orm/utilities/index'
require 'couchbase-orm/utilities/has_many'
require 'couchbase-orm/utilities/ensure_unique'
require 'couchbase-orm/utilities/query_helper'
require 'couchbase-orm/utilities/ignored_properties'
require 'couchbase-orm/json_transcoder'

module CouchbaseOrm
  module ActiveRecordCompat
      # try to avoid dependencies on too many active record classes
      # by exemple we don't want to go down to the concept of tables

    extend ActiveSupport::Concern

    module ClassMethods
      def primary_key
        'id'
      end

      def base_class?
        true
      end

      # can't be an alias for now
      def column_names
        attribute_names
      end

      def abstract_class?
        false
      end

      def connected?
        true
      end

      def table_exists?
        true
      end

      def _reflect_on_association(_attribute)
        false
      end

      def type_for_attribute(attribute)
        attribute_types[attribute]
      end

      if ActiveModel::VERSION::MAJOR < 6
        def attribute_names
          attribute_types.keys
        end
      end
    end

    def _has_attribute?(attr_name)
      attribute_names.include?(attr_name.to_s)
    end

    def attribute_for_inspect(attr_name)
      value = send(attr_name)
      value.inspect
    end

    if ActiveModel::VERSION::MAJOR <= 6
      def format_for_inspect(value)
        if value.is_a?(String) && value.length > 50
          "#{value[0, 50]}...".inspect
        elsif value.is_a?(Date) || value.is_a?(Time)
          %("#{value.to_s(:db)}")
        else
          value.inspect
        end
      end

      def attribute_names
        self.class.attribute_names
      end

      def has_attribute?(attr_name)
        @attributes.key?(attr_name.to_s)
      end

      def attribute_present?(attribute)
        value = send(attribute)
        !value.nil? && !(value.respond_to?(:empty?) && value.empty?)
      end

      def _write_attribute(attr_name, value)
        @attributes.write_from_user(attr_name.to_s, value)
        value
      end

      def read_attribute(attr_name, &block)
        name = attr_name.to_s
        name = self.class.attribute_aliases[name] || name

        name = @primary_key if name == 'id' && @primary_key
        @attributes.fetch_value(name, &block)
      end
    end
  end

  class Document
    include ::ActiveModel::Model
    include ::ActiveModel::Dirty
    include ::ActiveModel::Attributes
    include ::ActiveModel::Serializers::JSON

    include ::ActiveModel::Validations
    include ::ActiveModel::Validations::Callbacks

    include ::ActiveRecord::Core
    include ActiveRecordCompat
    include Encrypt

    extend Enum

    define_model_callbacks :initialize, only: :after
    define_model_callbacks :create, :destroy, :save, :update

    Metadata = Struct.new(:cas)

    class MismatchTypeError < RuntimeError; end

    def initialize(model = nil, ignore_doc_type: false, **attributes)
      CouchbaseOrm.logger.debug { "Initialize model #{model} with #{attributes.to_s.truncate(200)}" }
      @__metadata__ = Metadata.new

      super()

      if model
        case model
        when Couchbase::Collection::GetResult
          doc = model.content || raise('empty response provided')
          type = doc.delete('type')
          doc.delete('id')

          if type && !ignore_doc_type && type.to_s != self.class.design_document
            raise CouchbaseOrm::Error::TypeMismatchError.new(
              "document type mismatch, #{type} != #{self.class.design_document}", self
            )
          end

          self.id = attributes[:id] if attributes[:id].present?
          @__metadata__.cas = model.cas

          assign_attributes(decode_encrypted_attributes(doc))
          clear_changes_information
        when CouchbaseOrm::Base
          clear_changes_information
          super(model.attributes.except(:id, 'type'))
        else
          clear_changes_information
          super(decode_encrypted_attributes(**attributes.merge(Hash(model))))
        end
      else
        clear_changes_information
        super(attributes)
      end

      yield self if block_given?

      run_callbacks :initialize
    end

    def attributes
      super.with_indifferent_access
    end

    def [](key)
      send(key)
    end

    def []=(key, value)
      send(:"#{key}=", value)
    end

    protected

    def serialized_attributes
      encode_encrypted_attributes.map { |k, v|
        [k, self.class.attribute_types[k].serialize(v)]
      }.to_h
    end
  end

  class NestedDocument < Document
    def initialize(*args, **kwargs)
      super
      return unless respond_to?(:id) && id.nil?

      assign_attributes(id: SecureRandom.hex)
    end

    def ==(other)
      other.instance_of?(self.class) &&
        ((respond_to?(:id) && !id.nil? && other.id == id) || other.serialized_attributes == serialized_attributes)
    end
    alias eql? ==
  end

  class Base < Document
    include Persistence
    include ::ActiveRecord::AttributeMethods::Dirty
    include ::ActiveRecord::Validations # must be included after Persistence
    include ::ActiveRecord::Timestamp # must be included after Persistence

    include Associations
    include Views
    include QueryHelper
    include N1ql
    include Relation

    extend Join
    extend Enum
    extend EnsureUnique
    extend HasMany
    extend Index
    extend IgnoredProperties

    class << self
      def connect(**options)
        @bucket = BucketProxy.new(::MTLibcouchbase::Bucket.new(**options))
      end

      def bucket=(bucket)
        @bucket = bucket.is_a?(BucketProxy) ? bucket : BucketProxy.new(bucket)
      end

      def bucket
        @bucket ||= BucketProxy.new(Connection.bucket)
      end

      def cluster
        Connection.cluster
      end

      def collection
        CollectionProxy.new(bucket.default_collection)
      end

      def uuid_generator
        @uuid_generator ||= IdGenerator
      end

      attr_writer :uuid_generator

      def find(*ids, **options)
        CouchbaseOrm.logger.debug { "Base.find(l##{ids.length}) #{ids}" }

        chunck = (options.delete(:chunck) || 25).to_i
        quiet = options.delete(:quiet) || false
        ids = ids.flatten.select(&:present?)
        if ids.empty?
          raise CouchbaseOrm::Error::EmptyNotAllowed.new('no id(s) provided') unless quiet
          return nil if quiet
        end

        records = ids.each_slice(chunck).each_with_object([]) do |chunck_ids, res|
          data = Array.wrap(_find_records(chunck_ids, quiet))
          res.push(*data) unless data.empty?
        end

        ids.length > 1 ? records : records.first
      end

      def find_by_id(*ids, **options)
        options[:quiet] = true
        find(*ids, **options)
      end
      alias [] find_by_id

      def exists?(id)
        CouchbaseOrm.logger.debug { "Data - Exists? #{id}" }
        collection.exists(id).exists
      end
      alias has_key? exists?

      private

      def _find_records(ids, quiet)
        transcoder = CouchbaseOrm::JsonTranscoder.new(ignored_properties: ignored_properties)
        data = if quiet
                 collection.get_multi(ids, transcoder: transcoder)
               else
                 collection.get_multi!(ids, transcoder: transcoder)
               end.to_a
        Array.wrap(data).zip(ids).each_with_object([]) do |pair, records|
          records << self.new(pair[0], id: pair[1]) if pair[0]
        end
      end
    end

    def id=(value)
      raise 'ID cannot be changed' if @__metadata__.cas && value

      attribute_will_change!(:id)
      _write_attribute('id', value)
    end

      # Public: Allows for access to ActiveModel functionality.
      #
      # Returns self.
    def to_model
      self
    end

      # Public: Hashes identifying properties of the instance
      #
      # Ruby normally hashes an object to be used in comparisons.  In our case
      # we may have two techincally different objects referencing the same entity id.
      #
      # Returns a string representing the unique key.
    def hash
      "#{self.class.name}-#{self.id}-#{@__metadata__.cas}-#{@__attributes__.hash}".hash
    end

      # Public: Overrides eql? to use == in the comparison.
      #
      # other - Another object to compare to
      #
      # Returns a boolean.
    def eql?(other)
      self == other
    end

      # Public: Overrides == to compare via class and entity id.
      #
      # other - Another object to compare to
      #
      # Returns a boolean.
    def ==(other)
      super || other.instance_of?(self.class) && !id.nil? && other.id == id
    end

    private

    def raise_validation_error
      raise CouchbaseOrm::Error::RecordInvalid.new(self)
    end
  end
end
