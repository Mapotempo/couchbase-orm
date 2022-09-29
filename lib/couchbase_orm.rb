# frozen_string_literal: true

require 'logger'
require 'active_support/lazy_load_hooks'

ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.expand_path('couchbase_orm/locale/en.yml', __dir__)
end

module CouchbaseOrm
  autoload :Error,       'couchbase_orm/error'
  autoload :Connection,  'couchbase_orm/connection'
  autoload :IdGenerator, 'couchbase_orm/id_generator'
  autoload :Base,        'couchbase_orm/base'
  autoload :HasMany,     'couchbase_orm/utilities/has_many'

  def self.logger
    @@logger ||= if defined?(Rails)
                   Rails.logger
                 else
                   Logger.new($stdout).tap do |l|
                     l.level = Logger::INFO unless ENV['COUCHBASE_ORM_DEBUG']
                   end
                 end
  end

  def self.logger=(logger)
    @@logger = logger
  end

  def self.try_load(id)
    was_array = id.is_a?(Array)
    query_id = if was_array && id.length == 1
                 id.first
               else
                 id
               end

    result = query_id.is_a?(Array) ? CouchbaseOrm::Base.bucket.default_collection.get_multi(query_id) : CouchbaseOrm::Base.bucket.default_collection.get(query_id)

    result = Array.wrap(result) if was_array

    return result.zip(id).map { |r, i| try_load_create_model(r, i) }.compact if result.is_a?(Array)

    try_load_create_model(result, id)
  end

  def self.try_load_create_model(result, id)
    ddoc = result&.content&.[]('type')
    return nil unless ddoc

    ::CouchbaseOrm::Base.descendants.each do |model|
      return model.new(result, id: id) if model.design_document == ddoc
    end
    nil
  end
end

# Provide Boolean conversion function
# See: http://www.virtuouscode.com/2012/05/07/a-ruby-conversion-idiom/
module Kernel
  private

  def Boolean(value)
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

    raise ArgumentError, "invalid value for Boolean(): \"#{value.inspect}\""
  end
end

class Boolean < TrueClass; end

# If we are using Rails then we will include the Couchbase railtie.
require 'couchbase_orm/railtie' if defined?(Rails)
