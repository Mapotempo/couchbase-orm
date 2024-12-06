# frozen_string_literal: true

require 'ostruct'
require File.expand_path('support', __dir__)
require File.expand_path('../lib/couchbase-orm/proxies/collection_proxy', __dir__)

class KOProxyfied
  def get(_key, _options = nil)
    raise Couchbase::Error::DocumentNotFound
  end

  def remove(_key, _options = nil)
    raise Couchbase::Error::DocumentNotFound
  end

  def get_multi(_key, _options = nil)
    [OpenStruct.new(error: Couchbase::Error::DocumentNotFound.new)]
  end

  def remove_multi(_key, _options = nil)
    [OpenStruct.new(error: Couchbase::Error::DocumentNotFound.new)]
  end

  def upsert_multi(_key, _options = nil)
    [OpenStruct.new(error: Couchbase::Error::CouchbaseError.new)]
  end
end

class OKProxyfied
  def get(_key, _options = nil)
    Object.new
  end

  def remove(_key, _options = nil)
    Object.new
  end

  def get_multi(_key, _options = nil)
    [OpenStruct.new(error: nil)]
  end

  def remove_multi(_key, _options = nil)
    [OpenStruct.new(error: nil)]
  end

  def upsert_multi(_key, _options = nil)
    [OpenStruct.new(error: nil)]
  end
end

describe CouchbaseOrm::CollectionProxy do
  describe '#initialize' do
    it { expect { described_class.new(nil) }.to raise_error(ArgumentError) }
  end

  describe '#get!' do
    subject(:ok_proxy) { described_class.new(OKProxyfied.new) }

    it { expect(ok_proxy.get('key')).not_to be_nil }

    context 'with error' do
      subject(:ko_proxy) { described_class.new(KOProxyfied.new) }

      it 'raises an error' do
        expect { ko_proxy.get!('key') }.to raise_error(Couchbase::Error::DocumentNotFound)
      end
    end
  end

  describe '#get' do
    subject(:ok_proxy) { described_class.new(OKProxyfied.new) }

    it { expect(ok_proxy.get('key')).not_to be_nil }

    context 'with error' do
      subject(:ko_proxy) { described_class.new(KOProxyfied.new) }

      it 'raises an error' do
        expect { ko_proxy.get('key') }.not_to raise_error
      end
    end
  end

  describe '#get_multi!' do
    subject(:ok_proxy) { described_class.new(OKProxyfied.new) }

    it { expect(ok_proxy.get_multi!('key')).not_to be_nil }

    context 'with error' do
      subject(:ko_proxy) { described_class.new(KOProxyfied.new) }

      it 'raises an error' do
        expect { ko_proxy.get_multi!('key') }.to raise_error(Couchbase::Error::DocumentNotFound)
      end
    end
  end

  describe '#get_multi' do
    subject(:ok_proxy) { described_class.new(OKProxyfied.new) }

    it { expect(ok_proxy.get_multi('key')).not_to be_nil }

    context 'with error' do
      subject(:ko_proxy) { described_class.new(KOProxyfied.new) }

      it 'raises an error' do
        expect { ko_proxy.get_multi('key') }.not_to raise_error
      end
    end
  end

  describe '#remove!' do
    subject(:ok_proxy) { described_class.new(OKProxyfied.new) }

    it { expect(ok_proxy.remove!('key')).not_to be_nil }

    context 'with error' do
      subject(:ko_proxy) { described_class.new(KOProxyfied.new) }

      it 'raises an error' do
        expect { ko_proxy.remove!('key') }.to raise_error(Couchbase::Error::DocumentNotFound)
      end
    end
  end

  describe '#remove' do
    subject(:ok_proxy) { described_class.new(OKProxyfied.new) }

    it { expect(ok_proxy.remove('key')).not_to be_nil }

    context 'with error' do
      subject(:ko_proxy) { described_class.new(KOProxyfied.new) }

      it 'raises an error' do
        expect { ko_proxy.remove('key') }.not_to raise_error
      end
    end
  end

  describe '#remove_multi!' do
    subject(:ok_proxy) { described_class.new(OKProxyfied.new) }

    it { expect(ok_proxy.remove_multi!(['key'])).not_to be_nil }

    context 'with error' do
      subject(:ko_proxy) { described_class.new(KOProxyfied.new) }

      it 'raises an error' do
        expect { ko_proxy.remove!('key') }.to raise_error(Couchbase::Error::DocumentNotFound)
      end
    end
  end

  describe '#remove_multi' do
    subject(:ok_proxy) { described_class.new(OKProxyfied.new) }

    it { expect(ok_proxy.remove_multi(['key'])).not_to be_nil }

    context 'with error' do
      subject(:ko_proxy) { described_class.new(KOProxyfied.new) }

      it 'raises an error' do
        expect { ko_proxy.remove_multi(['key']) }.not_to raise_error
      end
    end
  end

  describe '#upsert_multi!' do
    subject(:ok_proxy) { described_class.new(OKProxyfied.new) }

    it { expect(ok_proxy.upsert_multi!(['foo', {foo: 'bar'}, 'bar', {bar: 'some value'}])).not_to be_nil }

    context 'with error' do
      subject(:ko_proxy) { described_class.new(KOProxyfied.new) }

      it 'raises an error' do
        expect { ko_proxy.upsert_multi!(['foo', {foo: 'bar'}, 'bar', {bar: 'some value'}]) }.to raise_error(Couchbase::Error::CouchbaseError)
      end
    end
  end

  describe '#upsert_multi' do
    subject(:ok_proxy) { described_class.new(OKProxyfied.new) }

    it { expect(ok_proxy.upsert_multi(['foo', {foo: 'bar'}, 'bar', {bar: 'some value'}])).not_to be_nil }

    context 'with error' do
      subject(:ko_proxy) { described_class.new(KOProxyfied.new) }

      it 'raises an error' do
        expect { ko_proxy.upsert_multi(['foo', {foo: 'bar'}, 'bar', {bar: 'some value'}]) }.not_to raise_error
      end
    end
  end
end
