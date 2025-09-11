# frozen_string_literal: true

require "delegate"

module CouchbaseOrm
  # Lazily materializes to Array once, then delegates all calls to that Array.
  class ResultsProxy < SimpleDelegator
    def initialize(source)
      # Contract: source must at least respond_to?(:to_a)
      unless source.respond_to?(:to_a)
        raise ArgumentError, "Proxyfied object must respond to :to_a"
      end
      @source = source
      @array  = nil
      # SimpleDelegator needs an initial obj; we’ll supply it lazily via __getobj__
      super(nil)
    end

    # Ensure callers that explicitly want an Array get the materialized one.
    def to_a
      __getobj__
    end

    private

    # SimpleDelegator hook: return the underlying object to delegate to.
    # We memoize the array so `to_a` is computed only once.
    def __getobj__
      @array ||= @source.to_a
    end
  end
end
