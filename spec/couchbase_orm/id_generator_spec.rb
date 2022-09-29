# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

require 'couchbase_orm'
class IdTestModel < CouchbaseOrm::Base; end

describe CouchbaseOrm::IdGenerator do
  it 'does not generate ID clashes' do
    model = IdTestModel.new

    ids1 = []
    thread1 = Thread.new do
      10_000.times do
        ids1 << described_class.next(model)
      end
    end

    ids2 = []
    thread2 = Thread.new do
      10_000.times do
        ids2 << described_class.next(model)
      end
    end

    ids3 = []
    thread3 = Thread.new do
      10_000.times do
        ids3 << described_class.next(model)
      end
    end

    ids4 = []
    thread4 = Thread.new do
      10_000.times do
        ids4 << described_class.next(model)
      end
    end

    thread1.join
    thread2.join
    thread3.join
    thread4.join

    results = [ids1, ids2, ids3, ids4].flatten
    expect(results.uniq).to eq(results)
  end
end
