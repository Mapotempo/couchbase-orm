# frozen_string_literal: true

module CouchbaseOrm
  module EnsureUnique
    private

    def ensure_unique(attrs, name = nil, presence: true, &processor)
      # index uses a special bucket key to allow record lookups based on
      # the values of attrs. ensure_unique adds a simple lookup using
      # one of the added methods to identify duplicate
      name = index(attrs, name, presence: presence, &processor)

      validate do |record|
        errors.add(name, 'has already been taken') unless record.send("#{name}_unique?")
      end
    end
  end
end
