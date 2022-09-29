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
require 'couchbase_orm/error'
require 'couchbase_orm/views'
require 'couchbase_orm/n1ql'
require 'couchbase_orm/persistence'
require 'couchbase_orm/associations'
require 'couchbase_orm/types'
require 'couchbase_orm/relation'
require 'couchbase_orm/proxies/bucket_proxy'
require 'couchbase_orm/proxies/collection_proxy'
require 'couchbase_orm/utilities/join'
require 'couchbase_orm/utilities/enum'
require 'couchbase_orm/utilities/index'
require 'couchbase_orm/utilities/has_many'
require 'couchbase_orm/utilities/ensure_unique'
require 'couchbase_orm/utilities/query_helper'

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

    if ActiveModel::VERSION::MAJOR < 6
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
    end
  end

  class Base
    include ::ActiveModel::Model
    include ::ActiveModel::Dirty
    include ::ActiveModel::Attributes
    include ::ActiveModel::Serializers::JSON

    include ::ActiveModel::Validations
    include ::ActiveModel::Validations::Callbacks

    include ::ActiveRecord::Core
    include ActiveRecordCompat

    define_model_callbacks :initialize, only: :after
    define_model_callbacks :create, :destroy, :save, :update

    include Persistence
    include ::ActiveRecord::AttributeMethods::Dirty
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

    Metadata = Struct.new(:key, :cas)

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

      def find(*ids, quiet: false)
        CouchbaseOrm.logger.debug { "Base.find(l##{ids.length}) #{ids}" }

        ids = ids.flatten.select(&:present?)
        raise CouchbaseOrm::Error::EmptyNotAllowed, 'no id(s) provided' if ids.empty?

        records = quiet ? collection.get_multi(ids) : collection.get_multi!(ids)
        CouchbaseOrm.logger.debug { "Base.find found(#{records})" }
        records = records.zip(ids).map do |record, id|
          new(record, id: id) if record
        end
        records.compact!
        ids.length > 1 ? records : records[0]
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
    end

    class MismatchTypeError < RuntimeError; end

    # Add support for libcouchbase response objects
    def initialize(model = nil, ignore_doc_type: false, **attributes)
      CouchbaseOrm.logger.debug { "Initialize model #{model} with #{attributes.to_s.truncate(200)}" }
      @__metadata__ = Metadata.new

      super()

      if model
        case model
        when Couchbase::Collection::GetResult
          doc = HashWithIndifferentAccess.new(model.content) || raise('empty response provided')
          type = doc.delete(:type)
          doc.delete(:id)

          if type && !ignore_doc_type && type.to_s != self.class.design_document
            raise CouchbaseOrm::Error::TypeMismatchError.new(
              "document type mismatch, #{type} != #{self.class.design_document}", self
            )
          end

          self.id = attributes[:id] if attributes[:id].present?
          @__metadata__.cas = model.cas

          assign_attributes(doc)
        when CouchbaseOrm::Base
          clear_changes_information
          super(model.attributes.except(:id, 'type'))
        else
          clear_changes_information
          assign_attributes(**attributes.merge(Hash(model)).symbolize_keys)
        end
      else
        clear_changes_information
        super(attributes)
      end
      yield self if block_given?

      run_callbacks :initialize
    end

    # Document ID is a special case as it is not stored in the document
    attr_reader :id

    def id=(value)
      raise 'ID cannot be changed' if @__metadata__.cas && value

      attribute_will_change!(:id)
      @id = value.to_s.presence
    end

    def [](key)
      send(key)
    end

    def []=(key, value)
      send(:"#{key}=", value)
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
      "#{self.class.name}-#{id}-#{@__metadata__.cas}-#{@__attributes__.hash}".hash
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
      super || (other.instance_of?(self.class) && !id.nil? && other.id == id)
    end
  end
end
