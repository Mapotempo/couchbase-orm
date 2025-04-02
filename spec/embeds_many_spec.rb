# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

require File.expand_path('support', __dir__)

describe CouchbaseOrm::EmbedsMany do
  before do
    class Address < CouchbaseOrm::Base
      attribute :street, :string
    end

    class Person < CouchbaseOrm::Base
      embeds_many :addresses, class_name: 'Address'
    end
  end

  let(:raw_data) { [{ street: '123 Main St' }, { street: '456 Elm St' }] }

  it 'defines an attribute with default empty array' do
    person = Person.new
    expect(person.addresses).to eq([])
  end

  it 'returns embedded instances with @_embedded = true' do
    person = Person.new(addresses: raw_data)
    addresses = person.addresses

    expect(addresses.size).to eq(2)
    expect(addresses.first).to be_a(Address)
    expect(addresses.first.instance_variable_get(:@_embedded)).to be true
  end

  it 'sets embedded flag on assignment' do
    new_addresses = raw_data.map { |data| Address.new(data) }
    person = Person.new
    person.addresses = new_addresses

    new_addresses.each do |addr|
      expect(addr.instance_variable_get(:@_embedded)).to be true
    end
  end

  it 'memoizes the embedded collection after first access' do
    person = Person.new(addresses: raw_data)
    first_call = person.addresses
    second_call = person.addresses

    expect(first_call).to equal(second_call)
  end

  it 'lazily loads the embedded collection only on first access' do
    person = Person.new(addresses: raw_data)

    expect(person.instance_variable_defined?(:@__assoc_addresses)).to be false

    _ = person.addresses

    expect(person.instance_variable_defined?(:@__assoc_addresses)).to be true
  end

  describe 'embedded object from embeds_many' do
    subject { person.addresses.first }

    let(:address) { Address.new(street: 'forbidden') }
    let(:person) do
      person = Person.new(addresses: [address])
      person.save!
      person
    end

    it 'raises when trying to save/save! an embedded document' do
      expect { subject.save }.to raise_error('Cannot save an embedded document!')
      expect { subject.save! }.to raise_error('Cannot save! an embedded document!')
    end

    it 'raises when trying to destroy/destroy! an embedded document' do
      expect { subject.destroy }.to raise_error('Cannot destroy an embedded document!')
      expect { subject.destroy! }.to raise_error('Cannot destroy an embedded document!')
    end

    it 'raises when trying to update/update_attribute/update_attributes an embedded document' do
      expect { subject.update(street: 'new value') }.to raise_error('Cannot update an embedded document!')
      expect { subject.update_attribute(:street, 'new value') }.to raise_error('Cannot update_attribute an embedded document!')
      expect { subject.update_attributes(street: 'new value') }.to raise_error('Cannot update an embedded document!')
    end

    it 'raises when trying to delete/remove an embedded document' do
      expect { subject.remove }.to raise_error('Cannot delete an embedded document!')
      expect { subject.delete }.to raise_error('Cannot delete an embedded document!')
    end

    it 'raises when trying to update_columns an embedded document' do
      expect { subject.update_columns(street: 'new value') }.to raise_error('Cannot update_columns an embedded document!')
    end

    it 'raises when trying to reload an embedded document' do
      expect { subject.reload }.to raise_error('Cannot reload an embedded document!')
    end

    it 'raises when trying to touch an embedded document' do
      expect { subject.touch }.to raise_error('Cannot touch an embedded document!')
    end
  end

  describe 'recursive embeds_many loop' do
    before do
      class Category < CouchbaseOrm::Base
        extend CouchbaseOrm::EmbedsMany

        attribute :name, :string
        embeds_many :subcategories, class_name: 'Category'
      end
    end

    it 'can embed subcategories recursively' do
      sub = Category.new(name: 'Sub')
      parent = Category.new(name: 'Parent', subcategories: [sub])

      expect(parent.subcategories.first.name).to eq('Sub')
      expect(parent.subcategories.first).to be_a(Category)
    end

    it 'does not infinitely loop when embedding recursively' do
      root = Category.new(name: 'Root')
      child = Category.new(name: 'Child')
      root.subcategories = [child]

      expect {
        # Simulate serialization (like save)
        root.send(:serialized_attributes)
      }.not_to raise_error
    end

    it 'can support multi-level nesting safely' do
      lvl3 = Category.new(name: 'Level 3')
      lvl2 = Category.new(name: 'Level 2', subcategories: [lvl3])
      lvl1 = Category.new(name: 'Level 1', subcategories: [lvl2])
      root = Category.new(name: 'Root', subcategories: [lvl1])

      expect(root.subcategories.first.subcategories.first.subcategories.first.name).to eq('Level 3')
    end
  end
end
