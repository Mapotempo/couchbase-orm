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
  end
end
