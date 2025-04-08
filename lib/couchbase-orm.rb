# frozen_string_literal: true

require 'logger'
require 'active_support/lazy_load_hooks'

# Add English locale config to load path by default.
ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.expand_path('couchbase-orm/locale/en.yml', __dir__)
end

# Top-level module for project.
module CouchbaseOrm
  autoload :Encrypt, 'couchbase-orm/encrypt'
  autoload :Error,       'couchbase-orm/error'
  autoload :Connection,  'couchbase-orm/connection'
  autoload :IdGenerator, 'couchbase-orm/id_generator'
  autoload :Base,        'couchbase-orm/base'
  autoload :Document, 'couchbase-orm/base'
  autoload :NestedDocument, 'couchbase-orm/base'
  autoload :HasMany, 'couchbase-orm/utilities/has_many'
  autoload :AttributesDynamic, 'couchbase-orm/attributes/dynamic'

  # if COUCHBASE_ORM_DEBUG environement variable exist then logger is set to Logger::DEBUG level
  # else logger is set to Logger::INFO level
  # @return [ Logger ] current logger setted for CouchbaseOrm
  def self.logger
    @@logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT).tap { |l|
                                                    l.level = Logger::INFO unless ENV['COUCHBASE_ORM_DEBUG']
                                                  }
  end

  # Allows you to set a logger for CouchbaseOrm,
  # which can be usueful for logging messages or errors related to CouchbaseOrm
  # @param [ Logger ] logger your custom logger
  #
  # @example Setting the logger in code
  #   require 'logger'
  #   my_logger = Logger.new(STDOUT)
  #   my_logger.level = Logger::DEBUG
  #   CouchbaseOrm.logger =  my_logger
  #
  # @return [ Logger ] the new logger setted
  def self.logger=(logger)
    @@logger = logger
  end

  # Attempts to load a record or records from the Couchbase database.
  #
  # This method can handle both single IDs and arrays of IDs.
  # It adapts its behavior based on the type and quantity of the input.
  #
  # @param [String, Array<String>] id The ID or array of IDs of the records to load.
  # @return [Object, Array<Object>] The loaded model(s). Returns an array of models if the input was an array, or a single model if the input was a single ID.
  def self.try_load(id)
    result = nil
    was_array = id.is_a?(Array)
    query_id = if was_array && id.length == 1
                 id.first
               else
                 id
               end

    result = query_id.is_a?(Array) ? CouchbaseOrm::Base.bucket.default_collection.get_multi(query_id) : CouchbaseOrm::Base.bucket.default_collection.get(query_id)

    result = Array.wrap(result) if was_array

    if result&.is_a?(Array)
      return result.zip(id).map { |r, id| try_load_create_model(r, id) }.compact
    end

    try_load_create_model(result, id)
  end

  # Creates a model from the fetched data and ID.
  #
  # This method checks the type of the fetched document and matches it against the design documents of known models.
  # If a match is found, it creates and returns an instance of the corresponding model.
  #
  # @param [Object] result The fetched record data. Expected to have a `content` method that returns a hash.
  # @param [String] id The ID of the record.
  # @return [Object, nil] The created model if a matching model is found, or `nil` if no match is found or if the document type is not present.
  def self.try_load_create_model(result, id)
    ddoc = result&.content&.[]('type')
    return nil unless ddoc

    ::CouchbaseOrm::Base.descendants.each do |model|
      if model.design_document == ddoc
        return model.instantiate(result.content, id, nil, model)
      end
    end
    nil
  end
end

# Add method to the Kernel module, making it available in all Ruby objects since Kernel is included by Object.
# See: http://www.virtuouscode.com/2012/05/07/a-ruby-conversion-idiom/
module Kernel
  private

  # Converts a given value to a Boolean.
  #
  # This method attempts to convert different types of values to their boolean equivalents.
  # - Strings and Symbols: 'true' (case-insensitive) is converted to true, 'false' (case-insensitive) is converted to false.
  # - Integers: 0 is converted to false, non-zero integers are converted to true.
  # - `false` and `nil` are converted to false.
  # - `true` is converted to true.
  # @see http://www.virtuouscode.com/2012/05/07/a-ruby-conversion-idiom/
  # @param [Object] value The value to be converted to a Boolean.
  # @return [Boolean] The Boolean representation of the given value.
  # @raise [ArgumentError] If the value cannot be converted to a Boolean.
  # @example Converting various values to Boolean
  #   include Kernel
  #
  #   Boolean('true')    # => true
  #   Boolean(' false ') # => false
  #   Boolean(:true)     # => true
  #   Boolean(:false)    # => false
  #   Boolean(1)         # => true
  #   Boolean(0)         # => false
  #   Boolean(nil)       # => false
  #   Boolean(true)      # => true
  #   Boolean(false)     # => false
  #
  #   # Invalid conversion raises ArgumentError
  #   begin
  #     Boolean('not a boolean')
  #   rescue ArgumentError => e
  #     e.message  # => "invalid value for Boolean(): \"not a boolean\""
  #   end
  def Boolean(value) # rubocop:disable Naming/MethodName
    case value
    when String, Symbol
      case value.to_s.strip.downcase
      when 'true'
        return true
      when 'false'
        return false
      end
    when Integer
      return value != 0
    when false, nil
      return false
    when true
      return true
    end

    raise ArgumentError.new("invalid value for Boolean(): \"#{value.inspect}\"")
  end
end

class Boolean < TrueClass; end

# If we are using Rails then we will include the Couchbase railtie.
if defined?(Rails)
  require 'couchbase-orm/railtie'
end
