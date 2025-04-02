# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

require 'active_model'
require 'active_support/hash_with_indifferent_access'

# rubocop:disable Metrics/ModuleLength
module CouchbaseOrm
  module Persistence
    extend ActiveSupport::Concern

    include Encrypt

    included do
      attribute :id, :string
    end

    Metadata = Struct.new(:cas)

    module ClassMethods
      def create(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create(attr, &block) }
        else
          instance = new(attributes, &block)
          instance.save
          instance
        end
      end

      def create!(attributes = nil, &block)
        if attributes.is_a?(Array)
          attributes.collect { |attr| create!(attr, &block) }
        else
          instance = new(attributes, &block)
          instance.save!
          instance
        end
      end

      # Raise an error if validation failed.
      def fail_validate!(document)
        raise Error::RecordInvalid.new(document)
      end

      # Allow classes to overwrite the default document name
      # extend ActiveModel::Naming (included by ActiveModel::Model)
      def design_document(name = nil)
        return @design_document unless name

        @design_document = name.to_s
      end

      # Set a default design document
      def inherited(child)
        super
        child.instance_eval do
          @design_document = child.name.underscore
        end
      end

      def instantiate(attributes, id, cas, klass)
        # attributes = decode_encrypted_attributes(attributes)
        type = attributes.delete('type')
        if type && type.to_s != klass.design_document
          raise CouchbaseOrm::Error::TypeMismatchError.new(
            "document type mismatch, #{type} != #{klass.design_document}", self
          )
        end

        # Use ActiveModel::AttributeSet::Builder to build attributes
        builder = attributes_builder
        attribute_set = builder.build_from_database(attributes)

        # Allocate and initialize the object
        instance = klass.allocate
        instance.init_with('attributes' => attribute_set, 'id' => id, 'cas' => cas, 'new_record' => false) # Custom initialization method
        instance
      end
    end

    def init_with(coder)
      @__metadata__ = Metadata.new
      @attributes = coder['attributes']
      CouchbaseOrm.logger.debug { "Initialize model #{self.class} with #{@attributes&.to_s&.truncate(200)}" }

      init_internals

      @new_record = coder['new_record']

      unless @new_record
        @attributes.write_from_database('id', coder['id'])
        @__metadata__.cas = coder['cas']
      end

      self.class.define_attribute_methods

      yield self if block_given?

      run_callbacks :find
      run_callbacks :initialize

      self
    end

    # Returns true if this object hasn't been saved yet -- that is, a record
    # for the object doesn't exist in the database yet; otherwise, returns false.
    def new_record?
      @__metadata__.cas.nil?
    end

    alias new? new_record?

    # Returns true if this object has been destroyed, otherwise returns false.
    def destroyed?
      @destroyed
    end

    # Returns true if the record is persisted, i.e. it's not a new record and it was
    # not destroyed, otherwise returns false.
    def persisted?
      !new_record? && !destroyed?
    end

    alias exists? persisted?

    def embedded?
      !!@_embedded
    end

    # Saves the model.
    #
    # If the model is new, a record gets created in the database, otherwise
    # the existing record gets updated.
    def save(**options)
      raise 'Cannot save an embedded document!' if embedded?
      raise 'Cannot save a destroyed document!' if destroyed?

      @_with_cas = options[:with_cas]
      create_or_update
    end

    # Saves the model.
    #
    # If the model is new, a record gets created in the database, otherwise
    # the existing record gets updated.
    #
    # By default, #save! always runs validations. If any of them fail
    # CouchbaseOrm::Error::RecordInvalid gets raised, and the record won't be saved.
    def save!(**options)
      raise 'Cannot save! an embedded document!' if embedded?

      self.class.fail_validate!(self) unless self.save(**options)
      self
    end

    # Deletes the record in the database and freezes this instance to
    # reflect that no changes should be made (since they can't be
    # persisted). Returns the frozen instance.
    #
    # The record is simply removed, no callbacks are executed.
    def delete(**options)
      raise 'Cannot delete an embedded document!' if embedded?

      options[:cas] = @__metadata__.cas if options.delete(:with_cas)
      CouchbaseOrm.logger.debug "Data - Delete #{self.id}"
      self.class.collection.remove(self.id, **options)

      self.id = nil
      clear_changes_information
      @destroyed = true
      self.freeze
      self
    end

    alias remove delete

    # Deletes the record in the database and freezes this instance to reflect
    # that no changes should be made (since they can't be persisted).
    #
    # There's a series of callbacks associated with #destroy.
    def destroy(**options)
      raise 'Cannot destroy an embedded document!' if embedded?

      return self if destroyed?
      raise 'model not persisted' unless persisted?

      run_callbacks :destroy do
        destroy_associations!

        options[:cas] = @__metadata__.cas if options.delete(:with_cas)
        CouchbaseOrm.logger.debug "Data - Destroy #{id}"
        self.class.collection.remove(id, **options)

        self.id = nil

        clear_changes_information
        @destroyed = true
        freeze
      end
    end

    alias destroy! destroy

    # Updates a single attribute and saves the record.
    # This is especially useful for boolean flags on existing records. Also note that
    #
    # * Validation is skipped.
    # * \Callbacks are invoked.
    def update_attribute(name, value)
      raise 'Cannot update_attribute an embedded document!' if embedded?

      public_send(:"#{name}=", value)
      changed? ? save(validate: false) : true
    end

    def assign_attributes(hash)
      super(hash.except('type'))
    end

    # Updates the attributes of the model from the passed-in hash and saves the
    # record. If the object is invalid, the saving will fail and false will be returned.
    def update(hash)
      raise 'Cannot update an embedded document!' if embedded?

      assign_attributes(hash)
      save
    end

    alias update_attributes update

    # Updates its receiver just like #update but calls #save! instead
    # of +save+, so an exception is raised if the record is invalid and saving will fail.
    def update!(hash)
      assign_attributes(hash) # Assign attributes is provided by ActiveModel::AttributeAssignment
      save!
    end

    alias update_attributes! update!

    # Updates the record without validating or running callbacks.
    # Updates only the attributes that are passed in as parameters
    # except if there is more than 16 attributes, in which case
    # the whole record is saved.
    def update_columns(with_cas: false, **hash)
      raise 'Cannot update_columns an embedded document!' if embedded?
      raise 'unable to update columns, model not persisted' unless id

      assign_attributes(hash)

      options = { extended: true }
      options[:cas] = @__metadata__.cas if with_cas

      # There is a limit of 16 subdoc operations per request
      resp = if hash.length <= 16
               self.class.collection.mutate_in(
                 id,
                 hash.map { |k, v| Couchbase::MutateInSpec.replace(k.to_s, v) }
               )
             else
               # Fallback to writing the whole document
               raw = serialized_attributes.except('id').merge(type: self.class.design_document)
               CouchbaseOrm.logger.debug { "Data - Replace #{id} #{raw.to_s.truncate(200)}" }
               self.class.collection.replace(id, raw, **options)
             end

      # Ensure the model is up to date
      @__metadata__.cas = resp.cas

      changes_applied
      self
    end

    # Reloads the record from the database.
    #
    # This method finds record by its key and modifies the receiver in-place:
    def reload
      raise 'Cannot reload an embedded document!' if embedded?
      raise 'unable to reload, model not persisted' unless id

      CouchbaseOrm.logger.debug "Data - Get #{id}"
      resp = self.class.collection.get!(id)
      assign_attributes(resp.content.except('id')) # API return a nil id
      @__metadata__.cas = resp.cas

      reset_associations
      clear_changes_information
      self
    end

    # Updates the TTL of the document
    def touch(**options)
      raise 'Cannot touch an embedded document!' if embedded?

      CouchbaseOrm.logger.debug "Data - Touch #{id}"
      _res = self.class.collection.touch(id, async: false, **options)
      @__metadata__.cas = resp.cas
      self
    end

    private

    def create_or_update(*)
      self.new_record? ? _create_record : _update_record
    end

    def _update_record(*)
      return true unless changed? || self.class.attribute_types.any? { |_, type|
        type.is_a?(CouchbaseOrm::Types::Nested) || type.is_a?(CouchbaseOrm::Types::Array)
      }

      run_callbacks :update do
        run_callbacks :save do
          options = {}
          options[:cas] = @__metadata__.cas if @_with_cas
          raw = serialized_attributes.except('id').merge(type: self.class.design_document)
          CouchbaseOrm.logger.debug { "_update_record - replace #{id} #{raw.to_s.truncate(200)}" }
          resp = self.class.collection.replace(id, raw, Couchbase::Options::Replace.new(**options))

          # Ensure the model is up to date
          @__metadata__.cas = resp.cas

          changes_applied
          true
        end
      end
    end

    def _create_record(*)
      run_callbacks :create do
        run_callbacks :save do
          assign_attributes(id: self.class.uuid_generator.next(self)) unless self.id
          raw = serialized_attributes.except('id').merge(type: self.class.design_document)
          CouchbaseOrm.logger.debug { "_create_record - Upsert #{id} #{raw.to_s.truncate(200)}" }
          resp = self.class.collection.upsert(self.id, raw, Couchbase::Options::Upsert.new)

          # Ensure the model is up to date
          @__metadata__.cas = resp.cas

          changes_applied
          true
        end
      end
    end
  end
end
# rubocop:enable Metrics/ModuleLength
