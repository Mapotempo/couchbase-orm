# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

require File.expand_path('support', __dir__)

class AttributeDynamicTest < CouchbaseOrm::Base
  include CouchbaseOrm::AttributesDynamic

  attribute :name, :string
  attribute :job, :string
end

describe CouchbaseOrm::AttributesDynamic do
  context 'from initialize' do
    it 'accepts unknown attribute from initialize' do
      dynamic = AttributeDynamicTest.new(name: 'joe', new_attribute: 1)
      expect(dynamic.new_attribute).to eq(1)
    end
  end

  context 'from Couchbase' do
    it 'accepts unknown attribute from Couchbase' do
      dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: 2)
      expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: 2)
      dynamic.destroy
    end

    context 'with integer' do
      it 'accepts unknown small integer from Coucbbase' do
        dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: 2)
        expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: 2)
        dynamic.destroy
      end

      it 'accepts unknown long integer from Coucbbase' do
        dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: 202302241231)
        expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: 202302241231)
        dynamic.destroy
      end
    end

    context 'with decimal' do
      it 'accepts unknown small decimal from Coucbbase' do
        dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: 2.0)
        expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: 2.0)
        dynamic.destroy
      end

      it 'accepts unknown long decimal from Coucbbase' do
        dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: 2.02302241231)
        expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: 2.02302241231)
        dynamic.destroy
      end
    end

    context 'with true_class' do
      it 'accepts unknown attribute from Coucbbase' do
        dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: true)
        expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: true)
        dynamic.destroy
      end
    end

    context 'with false_class' do
      it 'accepts unknown attribute from Coucbbase' do
        dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: false)
        expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: false)
        dynamic.destroy
      end
    end

    context 'with string' do
      it 'accepts unknown attribute from Coucbbase' do
        dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: 'a string')
        expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: 'a string')
        dynamic.destroy
      end
    end

    context 'with hash' do
      it 'accepts unknown attribute from Coucbbase' do
        dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: { a: 'hash' })
        expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: { a: 'hash' })
        dynamic.destroy
      end
    end

    context 'with nil' do
      it 'accepts unknown attribute from Coucbbase' do
        dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: nil)
        expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: nil)
        dynamic.destroy
      end
    end

    context 'with array' do
      it 'accepts unknown attribute from Coucbbase' do
        dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: [{ a: 'hash' }])
        expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: [{ a: 'hash' }])
        dynamic.destroy
      end
    end

    context 'with raw' do
      it 'not accepts to change string to number' do
        dynamic = AttributeDynamicTest.create!(name: 'joe', new_attribute: 'an string')
        dynamic.new_attribute = 1
        dynamic.save!
        expect(AttributeDynamicTest.find_by_id(dynamic.id)).to have_attributes(new_attribute: '1')
        dynamic.destroy!
      end
    end
  end
end
