# frozen_string_literal: true

require 'logger'
require 'active_model'
require File.expand_path('support', __dir__)

class Address < CouchbaseOrm::Base
  attribute :street, :string
  validates :street, presence: true
end

class Profile < CouchbaseOrm::Base
  attribute :bio, :string
  validates :bio, presence: true
end

class User < CouchbaseOrm::Base
  embeds_one :profile, class_name: 'Profile'
  embeds_many :addresses, class_name: 'Address'

  embeds_one :old_profile, class_name: 'Profile', validate: false
  embeds_many :old_addresses, class_name: 'Address', validate: false
end

describe CouchbaseOrm::EmbeddedAssociatedValidator do
  context 'with embeds_one' do
    it 'adds errors from invalid embedded object' do
      user = User.new(profile: Profile.new(bio: nil))

      expect(user).not_to be_valid
      expect(user.errors[:profile]).to include('is invalid')
      expect(user.errors[:profile_bio]).to include("can't be blank")
    end

    it 'passes validation when embedded object is valid' do
      user = User.new(profile: Profile.new(bio: 'Engineer'))

      expect(user).to be_valid
    end

    it 'passes validation when embedded object is invalid with validate deactivate' do
      user = User.new(profile: Profile.new(bio: 'Engineer'), old_profile: Profile.new)

      expect(user).to be_valid
      expect(user.old_profile).not_to be_valid
    end
  end

  context 'with embeds_many' do
    it 'adds errors for each invalid embedded object with index' do
      user = User.new(addresses: [Address.new(street: nil), Address.new(street: '42 Rue du Code')])

      expect(user).not_to be_valid
      expect(user.errors[:addresses]).to include('item #0 is invalid')
      expect(user.errors[:addresses_0_street]).to include("can't be blank")
      expect(user.errors[:addresses_1_street]).to be_blank # No error
    end

    it 'passes validation when all embedded objects are valid' do
      user = User.new(addresses: [Address.new(street: '123 Main St'), Address.new(street: '456 Elm St')])

      expect(user).to be_valid
    end

    it 'passes validation when embedded object is invalid with validate deactivate' do
      user = User.new(addresses: [Address.new(street: '123 Main St'), Address.new(street: '456 Elm St')], old_addresses: [Address.new])

      expect(user).to be_valid
      expect(user.old_addresses.first).not_to be_valid
    end
  end
end
