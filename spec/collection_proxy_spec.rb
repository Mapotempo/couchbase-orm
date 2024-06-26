# frozen_string_literal: true

require File.expand_path('support', __dir__)
require File.expand_path('../lib/couchbase-orm/proxies/collection_proxy', __dir__)

class Proxyfied
  def get(_key, _options = nil)
    raise Couchbase::Error::DocumentNotFound
  end

  def remove(_key, _options = nil)
    raise Couchbase::Error::DocumentNotFound
  end
end

describe CouchbaseOrm::CollectionProxy do
  it 'raises an error when get is called with bang version' do
    expect {
      CouchbaseOrm::CollectionProxy.new(Proxyfied.new).get!('key')
    }.to raise_error(Couchbase::Error::DocumentNotFound)
  end

  it 'does not raise an error when get is called with non bang version' do
    expect { CouchbaseOrm::CollectionProxy.new(Proxyfied.new).get('key') }.not_to raise_error
  end

  it 'raises an error when remove is called with bang version' do
    expect {
      CouchbaseOrm::CollectionProxy.new(Proxyfied.new).remove!('key')
    }.to raise_error(Couchbase::Error::DocumentNotFound)
  end

  it 'does not raise an error when remove is called with non bang version' do
    expect { CouchbaseOrm::CollectionProxy.new(Proxyfied.new).remove('key') }.not_to raise_error
  end
end
