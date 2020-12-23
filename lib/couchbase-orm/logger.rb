# frozen_string_literal: true, encoding: ASCII-8BIT

require 'logger'

module CouchbaseOrm
  LOG_LEVEL = Logger::DEBUG

  def logger
      Logging.logger
    end

  # Global, memoized, lazy initialized instance of a logger
  def self.logger
      @logger ||= Logger.new(STDOUT, level: LOG_LEVEL)
  end
end
