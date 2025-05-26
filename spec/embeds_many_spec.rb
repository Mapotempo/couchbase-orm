# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

require File.expand_path('support', __dir__)

class Address < CouchbaseOrm::Base
  attribute :street, :string
end

class Person < CouchbaseOrm::Base
  embeds_many :addresses, class_name: 'Address'
end

class Category < CouchbaseOrm::Base
  attribute :name, :string
  embeds_many :subcategories, class_name: 'Category'
end

class AliasPerson < CouchbaseOrm::Base
  embeds_many :addresses, store_as: 'a'
end

class BaseAddress < CouchbaseOrm::Base
  attribute :street, :string
  validates :street, presence: true
end

class ExtendedAddress < BaseAddress
  attribute :city, :string
end

class InheritedPerson < CouchbaseOrm::Base
  embeds_many :addresses, class_name: 'ExtendedAddress'
end

class BasePerson < CouchbaseOrm::Base
  embeds_many :addresses, class_name: 'Address'
end

class ChildPerson < BasePerson
end

class AddressBook < CouchbaseOrm::Base
  attribute :label, :string
  has_many :contacts, type: :n1ql, class_name: 'Contact'
end

class Contact < CouchbaseOrm::Base
  attribute :name, :string
  belongs_to :address_book
end

class PersonWithBook < CouchbaseOrm::Base
  embeds_many :address_books, class_name: 'AddressBook'
end

class City < CouchbaseOrm::Base
  attribute :name, :string
end

class AddressWithCity < CouchbaseOrm::Base
  attribute :street, :string
  belongs_to :city
end

class Citizen < CouchbaseOrm::Base
  embeds_many :addresses, class_name: 'AddressWithCity'
end

describe CouchbaseOrm::EmbedsMany do
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
    person = Person.create!(addresses: raw_data)
    person = Person.find(person.id)

    expect(person.instance_variable_defined?(:@__assoc_addresses)).to be false

    _ = person.addresses

    expect(person.instance_variable_defined?(:@__assoc_addresses)).to be true
  end

  it 'does not include id if id is blank in embedded' do
    person = Person.new(addresses: raw_data)
    expect(person.send(:serialized_attributes)['addresses'].first).not_to include('id')
  end

  it 'saves changes in embedded collection when parent is saved and reloads correctly' do
    person = Person.create!(addresses: [{ street: 'Initial St' }])

    person2 = Person.find(person.id)
    person2.addresses.first.street = 'Updated St'
    person2.addresses = person2.addresses
    person2.save!

    person.reload

    expect(person.addresses.first.street).to eq('Updated St')
  end

  describe 'with store_as / alias support' do
    it 'stores and retrieves using store_as alias' do
      person = AliasPerson.new(addresses: [{ street: '789 Oak St' }])
      person.save!

      # Re-fetch to ensure correct storage and retrieval
      loaded = AliasPerson.find(person.id)
      expect(loaded.addresses.first.street).to eq('789 Oak St')

      # Check raw attribute storage (simulate serialized JSON)
      raw = person.send(:serialized_attributes)
      expect(raw['a']).to be_an(Array)
      expect(raw['a'].first['street']).to eq('789 Oak St')
    end
  end

  describe 'embedded object from embeds_many' do
    subject(:embedded_address) { person.addresses.first }

    let(:address) { Address.new(street: 'forbidden') }
    let(:person) do
      person = Person.new(addresses: [address])
      person.save!
      person
    end

    it 'raises when trying to save/save! an embedded document' do
      expect { embedded_address.save }.to raise_error('Cannot save an embedded document!')
      expect { embedded_address.save! }.to raise_error('Cannot save! an embedded document!')
    end

    it 'raises when trying to destroy/destroy! an embedded document' do
      expect { embedded_address.destroy }.to raise_error('Cannot destroy an embedded document!')
      expect { embedded_address.destroy! }.to raise_error('Cannot destroy an embedded document!')
    end

    it 'raises when trying to update/update_attribute/update_attributes an embedded document' do
      expect { embedded_address.update(street: 'new value') }.to raise_error('Cannot update an embedded document!')
      expect { embedded_address.update_attribute(:street, 'new value') }.to raise_error('Cannot update_attribute an embedded document!')
      expect { embedded_address.update_attributes(street: 'new value') }.to raise_error('Cannot update an embedded document!')
    end

    it 'raises when trying to delete/remove an embedded document' do
      expect { embedded_address.remove }.to raise_error('Cannot delete an embedded document!')
      expect { embedded_address.delete }.to raise_error('Cannot delete an embedded document!')
    end

    it 'raises when trying to update_columns an embedded document' do
      expect { embedded_address.update_columns(street: 'new value') }.to raise_error('Cannot update_columns an embedded document!')
    end

    it 'raises when trying to reload an embedded document' do
      expect { embedded_address.reload }.to raise_error('Cannot reload an embedded document!')
    end

    it 'raises when trying to touch an embedded document' do
      expect { embedded_address.touch }.to raise_error('Cannot touch an embedded document!')
    end
  end

  describe 'recursive embeds_many loop' do
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

  it 'reflects embedded assign in serialized attributes' do
    person = Person.new(addresses: [{ street: 'Old St' }])
    person.addresses = [Address.new(street: 'New St')]

    serialized = person.send(:serialized_attributes)
    expect(serialized['addresses'].first['street']).to eq('New St')
  end

  it 'does not reflect embedded changes in serialized attributes' do
    person = Person.new(addresses: [{ street: 'Old St' }])
    person.addresses.first.street = 'New St'

    serialized = person.send(:serialized_attributes)
    expect(serialized['addresses'].first['street']).not_to eq('New St')
  end

  it 'does not mark parent as changed when only embedded is modified (unless tracked)' do
    person = Person.create!(addresses: [{ street: 'Old St' }])
    person.reload

    expect(person.changed?).to be false

    person.addresses.first.street = 'New St'
    expect(person.changed?).to be false
  end

  it 'updates embedded attributes without replacing instances' do
    person = Person.new(addresses: [{ street: 'Initial' }])
    original = person.addresses.first
    person.addresses = [{ street: 'Updated' }]

    expect(person.addresses).not_to be_empty
    expect(person.addresses.first.street).to eq('Updated')
    expect(person.addresses.first).not_to equal(original)
  end

  it 'sets the embedded documents to empty when assigned nil' do
    person = Person.new(addresses: [{ street: 'Something' }])
    person.addresses = nil

    expect(person.addresses).to eq([])
    expect(person.attributes['addresses']).to eq([])
  end

  it 'returns readable inspect for embedded objects' do
    person = Person.new(addresses: [{ street: 'Visible' }])
    expect(person.addresses.first.inspect).to include('street')
  end

  it 'duplicates the embedded objects when parent is duped' do
    person = Person.new(addresses: [{ street: 'original' }])
    copy = person.dup

    expect(copy.addresses).not_to be_empty
    expect(copy.addresses.first.street).to eq('original')
    expect(copy.addresses.first).not_to equal(person.addresses.first)
  end

  describe 'embeds_many with inheritance' do
    let(:raw_data) { [{ street: 'Inherited St', city: 'Paris' }] }

    it 'instantiates the correct subclass in embedded field' do
      person = InheritedPerson.new(addresses: raw_data)

      expect(person.addresses.first).to be_a(ExtendedAddress)
      expect(person.addresses.first.street).to eq('Inherited St')
      expect(person.addresses.first.city).to eq('Paris')
    end

    it 'serializes the inherited fields correctly' do
      person = InheritedPerson.new(addresses: raw_data)
      serialized = person.send(:serialized_attributes)

      expect(serialized['addresses'].first['street']).to eq('Inherited St')
      expect(serialized['addresses'].first['city']).to eq('Paris')
    end

    it 'validates inherited embedded object' do
      person = InheritedPerson.new(addresses: [{ city: 'No Street' }]) # street is required

      expect(person.valid?).to be false
      expect(person.errors[:addresses]).not_to be_empty
    end

    it 'raises when trying to save inherited embedded document directly' do
      embedded = ExtendedAddress.new(street: 'Oops', city: 'Lyon')
      embedded.instance_variable_set(:@_embedded, true)

      expect { embedded.save }.to raise_error('Cannot save an embedded document!')
    end
  end

  describe 'embedded registry inheritance with deep duplication' do
    it 'inherits embedded config from parent' do
      expect(ChildPerson.embedded.keys).to include(:addresses)
      expect(ChildPerson.embedded[:addresses][:class_name]).to eq(Address.to_s)
    end

    it 'modifying child embedded does not affect parent' do
      ChildPerson.embedded[:addresses][:class_name] = 'Overridden'
      expect(BasePerson.embedded[:addresses][:class_name]).to eq(Address.to_s)
    end
  end

  describe 'embeds_many with associations inside embedded object' do
    it 'can access a belongs_to association from embedded object' do
      city = City.create!(name: 'Paris')
      address = AddressWithCity.new(street: '12 Rue de Python', city: city)
      citizen = Citizen.new(addresses: [address])

      expect(citizen.addresses.first).to be_a(AddressWithCity)
      expect(citizen.addresses.first.city).to eq(city)
      expect(citizen.addresses.first.city.name).to eq('Paris')
    end

    it 'can access a has_many association from embedded object' do
      address_book = AddressBook.new(label: 'Work Contacts')
      address_book.id = AddressBook.uuid_generator.next(address_book)

      person = PersonWithBook.create!(address_books: [address_book])
      contact1 = Contact.create!(name: 'Alice', address_book: person.address_books.first)
      contact2 = Contact.create!(name: 'Bob', address_book: person.address_books.first)

      person = PersonWithBook.find(person.id)

      expect(person.address_books.first.contacts).to all(be_a(Contact))
      expect(person.address_books.first.contacts.map(&:name)).to include('Alice', 'Bob')
    ensure
      contact1.destroy! if contact1&.persisted?
      contact2.destroy! if contact2&.persisted?
      person.destroy! if person&.persisted?
    end
  end
end
