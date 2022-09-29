# frozen_string_literal: true

require 'couchbase_orm/proxies/results_proxy'

module CouchbaseOrm
  class N1qlProxy
    def initialize(proxyfied)
      @proxyfied = proxyfied

      self.class.define_method(:results) do |*_params, &block|
        @results = nil if @current_query != to_s
        @current_query = to_s
        return @results if @results

        CouchbaseOrm.logger.debug { "Query - #{self}" }

        results = @proxyfied.rows
        results = results.map { |r| block.call(r) } if block
        @results = ResultsProxy.new(results.to_a)
      end

      self.class.define_method(:to_s) do
        @proxyfied.to_s.tr("\n", ' ')
      end

      proxyfied.public_methods.each do |method|
        next if public_methods.include?(method)

        self.class.define_method(method) do |*params, &block|
          ret = @proxyfied.send(method, *params, &block)
          ret.is_a?(@proxyfied.class) ? self : ret
        end
      end
    end

    def method_missing(m, *args, &block)
      results.send(m, *args, &block)
    end
  end
end
