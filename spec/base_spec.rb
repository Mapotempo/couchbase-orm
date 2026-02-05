# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

require File.expand_path('support', __dir__)

class BaseTest < CouchbaseOrm::Base
  attribute :name, :string
  attribute :job, :string
  attribute :status, :string, default: 'active'
end

class CompareTest < CouchbaseOrm::Base
  attribute :age, :integer
end

class TimestampTest < CouchbaseOrm::Base
  attribute :created_at, :datetime, precision: 6
  attribute :deleted_at, :datetime, precision: 6
end

class BaseTestWithIgnoredProperties < CouchbaseOrm::Base
  ignored_properties :deprecated_property
  attribute :name, :string
  attribute :job, :string
end

describe CouchbaseOrm::Base do
  it 'is comparable to other objects' do
    base = BaseTest.create!(name: 'joe')
    base2 = BaseTest.create!(name: 'joe')
    base3 = BaseTest.create!(ActiveSupport::HashWithIndifferentAccess.new(name: 'joe'))

    expect(base).to eq(base)
    expect(base).to be(base)
    expect(base).not_to eq(base2)

    same_base = BaseTest.find(base.id)
    expect(base).to eq(same_base)
    expect(base).not_to be(same_base)
    expect(base2).not_to eq(same_base)

    base.delete
    base2.delete
    base3.delete
  end

  it 'is inspectable' do
    base = BaseTest.create!(name: 'joe')
    expect(base.inspect).to eq("#<BaseTest id: \"#{base.id}\", name: \"joe\", job: nil, status: \"active\">")
  end

  it 'loads database responses' do
    base = BaseTest.create!(name: 'joe')
    resp = BaseTest.bucket.default_collection.get(base.id)

    base_loaded = BaseTest.instantiate(resp.content, base.id, resp.cas, BaseTest)

    expect(base_loaded.id).to eq(base.id)
    expect(base_loaded).to eq(base)
    expect(base_loaded).not_to be(base)

    base.destroy
  end

  it 'does not load objects if there is a type mismatch' do
    base = BaseTest.create!(name: 'joe')

    expect { CompareTest.find_by_id(base.id) }.to raise_error(CouchbaseOrm::Error::TypeMismatchError)

    base.destroy
  end

  xit 'raises ActiveModel::UnknownAttributeError on loading objects with unexpected properties' do
    too_much_properties_doc = {
      type: BaseTest.design_document,
      name: 'Pierre',
      job: 'dev',
      age: '42'
    }
    base = BaseTest.new
    expect { base.assign_attributes(too_much_properties_doc) }.to raise_error(ActiveModel::UnknownAttributeError)
  end

  it 'loads objects even if there is a missing property in doc' do
    missing_properties_doc = {
      type: BaseTest.design_document,
      name: 'Pierre'
    }
    BaseTest.bucket.default_collection.upsert 'doc_1', missing_properties_doc
    base = BaseTest.find('doc_1')

    expect(base.name).to eq('Pierre')
    expect(base.job).to be_nil
    base.destroy
  end

  it 'supports serialisation' do
    base = BaseTest.create!(name: 'joe')

    base_id = base.id
    expect(base.to_json).to eq({ id: base_id, name: 'joe', job: nil, status: 'active', type: 'base_test' }.to_json)
    expect(base.to_json(only: :name)).to eq({ name: 'joe', type: 'base_test' }.to_json)

    base.destroy
  end

  it 'includes type and id fields in as_json for Base models' do
    base = BaseTest.create!(name: 'alice')
    json = base.as_json

    expect(json).to include('type' => 'base_test')
    expect(json).to include('id' => base.id)
    expect(json['name']).to eq('alice')

    base.destroy
  end

  it 'supports dirty attributes' do
    base = BaseTest.new
    expect(base.changes.empty?).to be(true)
    expect(base.previous_changes.empty?).to be(true)

    base.name = 'change'
    expect(base.changes.empty?).to be(false)

    # Attributes are set by key
    base = BaseTest.new
    base[:name] = 'bob'
    expect(base.changes.empty?).to be(false)

    # Attributes are set by initializer from hash
    base = BaseTest.new({ name: 'bob' })
    expect(base.changes.empty?).to be(false)
    expect(base.previous_changes.empty?).to be(true)

    # A saved model should have no changes
    base = BaseTest.create!(name: 'joe')
    expect(base.changes.empty?).to be(true)
    expect(base.previous_changes.empty?).to be(true)

    # Attributes are copied from the existing model
    # base = BaseTest.mew(base)
    # expect(base.changes.empty?).to be(false)
    # expect(base.previous_changes.empty?).to be(true)
  ensure
    base.destroy if base.persisted?
  end

  it 'tries to load a model with nothing but an ID' do
    base = BaseTest.create!(name: 'joe')
    obj = CouchbaseOrm.try_load(base.id)
    expect(obj).to eq(base)
  ensure
    base.destroy
  end

  it 'is able to create model with a custom ID' do
    base = BaseTest.create!(id: 'custom_id', name: 'joe')
    expect(base.id).to eq('custom_id')

    base = BaseTest.find('custom_id')
    expect(base.id).to eq('custom_id')
  ensure
    base&.destroy
  end

  it 'tries to load a model with nothing but single-multiple ID' do
    bases = [BaseTest.create!(name: 'joe')]
    objs = CouchbaseOrm.try_load(bases.map(&:id))
    expect(objs).to match_array(bases)
  ensure
    bases.each(&:destroy)
  end

  it 'tries to load a model with nothing but multiple ID' do
    bases = [BaseTest.create!(name: 'joe'), CompareTest.create!(age: 12)]
    objs = CouchbaseOrm.try_load(bases.map(&:id))
    expect(objs).to match_array(bases)
  ensure
    bases.each(&:destroy)
  end

  it 'sets the attribute on creation' do
    base = BaseTest.create!(name: 'joe')
    expect(base.name).to eq('joe')
  ensure
    base.destroy
  end

  it 'supports getting the attribute by key' do
    base = BaseTest.create!(name: 'joe')
    expect(base[:name]).to eq('joe')
  ensure
    base.destroy
  end

  it 'cannot change the id of a loaded object' do
    base = BaseTest.create!(name: 'joe')
    expect(base.id).not_to be_nil
    expect { base.id = 'foo' }.to raise_error(RuntimeError, 'ID cannot be changed')
  end

  it 'attributes should be HashWithIndifferentAccess' do
    base = BaseTest.create!(name: 'joe')
    expect(base.attributes.class).to be(HashWithIndifferentAccess)
  end

  if ActiveModel::VERSION::MAJOR >= 6
    it 'has timestamp attributes for create in model' do
      expect(TimestampTest.timestamp_attributes_for_create_in_model).to eq(['created_at'])
    end
  end

  it 'generates a timestamp on creation' do
    base = TimestampTest.create!
    expect(base.created_at).to be_a(Time)
  end

  it 'raises error when get object by nil id with quiet as false' do
    expect { BaseTest.find(nil, quiet: false) }.to raise_error(CouchbaseOrm::Error::EmptyNotAllowed)
  end

  it 'does not raise error when get object by nil id with quiet as true' do
    expect { BaseTest.find(nil, quiet: true) }.not_to raise_error
  end

  it 'does not mark object as dirty on get' do
    base = BaseTest.create!(name: 'joe')

    expect(BaseTest.find_by_id(base.id).changes).to be_empty

    base.destroy
  end

  it 'sets default value for attribute on creation' do
    base = BaseTest.create!(name: 'joe')
    expect(base.status).to eq('active')
  ensure
    base.destroy if base.persisted?
  end

  it 'applies default value when loading a document missing the attribute' do
    doc_id = 'test_doc_without_status'
    BaseTest.bucket.default_collection.upsert(doc_id, { type: BaseTest.design_document, name: 'joe' })

    loaded = BaseTest.find(doc_id)
    expect(loaded.status).to eq('active')
  ensure
    loaded.destroy if loaded.persisted?
  end

  describe BaseTest do
    it_behaves_like 'ActiveModel'
  end

  describe CompareTest do
    it_behaves_like 'ActiveModel'
  end

  describe '.ignored_properties' do
    it 'returns an array of ignored properties' do
      expect(BaseTestWithIgnoredProperties.ignored_properties).to eq(['deprecated_property'])
    end

    context 'given a document with ignored properties' do
      let(:doc_id) { 'doc_1' }
      let(:document_properties) do
        {
          'type' => BaseTestWithIgnoredProperties.design_document,
          'name' => 'Pierre',
          'job' => 'dev',
          'deprecated_property' => 'depracted that could be removed on next save'
        }
      end
      let(:loaded_model) { BaseTestWithIgnoredProperties.find(doc_id) }

      before { BaseTestWithIgnoredProperties.bucket.default_collection.upsert doc_id, document_properties }
      after { BaseTestWithIgnoredProperties.bucket.default_collection.remove doc_id }

      it 'ignores the ignored properties on load from db (and dont raise)' do
        expect(loaded_model.attributes.keys).not_to include('deprecated_property')
        expect(loaded_model.name).to eq('Pierre')
        expect(BaseTestWithIgnoredProperties.bucket.default_collection.get(doc_id).content).to include(document_properties)
      end

      # TODO: deprecated, need to rework
      xit 'delete the ignored properties on save' do
        base = BaseTestWithIgnoredProperties.find(doc_id)
        expect { loaded_model.save }.to change {
          BaseTestWithIgnoredProperties.bucket.default_collection.get(doc_id).content.keys.sort
        }
          .from(%w[deprecated_property job name type])
          .to(%w[job name type])
      end
    end
  end
end
