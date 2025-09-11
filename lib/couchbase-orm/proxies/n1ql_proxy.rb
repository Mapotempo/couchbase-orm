# frozen_string_literal: true

require 'couchbase-orm/proxies/results_proxy'
require 'monitor'

module CouchbaseOrm
  class N1qlProxy
    def initialize(proxyfied)
      @proxyfied = proxyfied
      @results   = nil
      @query_str = nil
      @dirty     = true
      @mon       = Monitor.new
    end

    # Return cached results unless the underlying query changed.
    # Yields each row through the optional block (mapping lazily when possible).
    def results(&block)
      # Fast-path read without locking if is not dirty and results already cached
      cached = @results
      return cached if !@dirty && cached

      @mon.synchronize do
        # Double-check under the lock
        return @results if !@dirty && @results

        CouchbaseOrm.logger.debug { "Query - #{query_str}" }

        rows = @proxyfied.rows
        rows = rows.lazy.map { |r| yield(r) } if block # lazy map avoids intermediate array
        # ResultsProxy historically takes an Array; if yours accepts any Enumerable,
        # drop the `.to_a` to stream. Otherwise, keep `.to_a`:
        @results = ResultsProxy.new(rows.respond_to?(:to_a) ? rows.to_a : rows)
        @dirty   = false
        @results
      end
    end

    # Stable, memoized string form of the query (no per-call allocations).
    def to_s
      query_str
    end

    def method_missing(method_name, *args, &blk)
      if @proxyfied.respond_to?(method_name)
        ret = @proxyfied.public_send(method_name, *args, &blk)
        if ret.is_a?(@proxyfied.class)
          mark_dirty!
          self
        else
          ret
        end
      else
        # Collection/query-result methods go to the realized results
        results.public_send(method_name, *args, &blk)
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @proxyfied.respond_to?(method_name, include_private) ||
        ResultsProxy.instance_methods.include?(method_name) ||
        Array.instance_methods.include?(method_name) || # common collection API
        super
    end

    private

    # Compute/refresh the normalized query string once per change.
    def query_str
      # If dirty, refresh under lock
      if @dirty || @query_str.nil?
        @mon.synchronize do
          if @dirty || @query_str.nil?
            # Avoid building new strings repeatedly; `tr` returns a new string once.
            @query_str = @proxyfied.to_s.tr("\n", ' ')
          end
        end
      end
      @query_str
    end

    def mark_dirty!
      # Clear cache cheaply; defer recompute to the next `results`/`to_s` call
      @dirty   = true
      @results = nil
      # No need to lock here; benign races are resolved in `results`/`query_str`
    end
  end
end
