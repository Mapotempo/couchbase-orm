# frozen_string_literal: true

require File.expand_path('support', __dir__)

describe 'CouchbaseOrm Railtie' do # rubocop:disable RSpec/DescribeClass
  it 'registers index config initializer after connection config initializer' do
    railtie_source = File.read(File.expand_path('../lib/couchbase-orm/railtie.rb', __dir__))

    expect(railtie_source).to include(
      "initializer 'couchbase_orm.setup_index_config', after: 'couchbase_orm.setup_connection_config'"
    )
  end
end
