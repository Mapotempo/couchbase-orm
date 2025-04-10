# frozen_string_literal: true

require File.expand_path('support', __dir__)

class Profile < CouchbaseOrm::Base
  attribute :bio, :string
  validates :bio, presence: true
end

class User < CouchbaseOrm::Base
  embeds_one :profile, class_name: 'Profile'
end

class Node < CouchbaseOrm::Base
  attribute :value, :string
  embeds_one :child, class_name: 'Node'
end

class AliasUser < CouchbaseOrm::Base
  embeds_one :profile, store_as: 'p'
end

class BaseProfile < CouchbaseOrm::Base
  attribute :bio, :string
  validates :bio, presence: true
end

class ExtendedProfile < BaseProfile
  attribute :title, :string
end

class InheritedUser < CouchbaseOrm::Base
  embeds_one :profile, class_name: 'ExtendedProfile'
end

class ParentModel < CouchbaseOrm::Base
  embeds_one :profile, class_name: 'Profile'
end

class ChildModel < ParentModel
end

describe CouchbaseOrm::EmbedsOne do
  let(:raw_data) { { bio: 'Software Engineer' } }

  it 'defines an attribute with default nil' do
    user = User.new
    expect(user.attributes['profile']).to be_nil
  end

  it 'returns nil if raw data is not present' do
    user = User.new
    expect(user.profile).to be_nil
  end

  it 'returns an embedded instance with @_embedded = true' do
    user = User.new(profile: raw_data)
    profile = user.profile

    expect(profile).to be_a(Profile)
    expect(profile.bio).to eq('Software Engineer')
    expect(profile.instance_variable_get(:@_embedded)).to be true
  end

  it 'sets embedded flag and serializes data on assignment' do
    new_profile = Profile.new(bio: 'DevOps Specialist')
    user = User.new
    user.profile = new_profile

    expect(user.profile).to eq(new_profile)
    expect(user.profile.instance_variable_get(:@_embedded)).to be true
    expect(user.attributes['profile']).to include('bio' => 'DevOps Specialist')
  end

  it 'supports resetting the cached embedded instance' do
    user = User.new(profile: raw_data)
    original = user.profile
    user.profile_reset

    new_instance = user.profile
    expect(new_instance).to be_a(Profile)
    expect(new_instance).not_to equal(original)
  end

  it 'memoizes the embedded instance after first access' do
    user = User.new(profile: raw_data)
    first_call = user.profile
    second_call = user.profile

    expect(first_call).to equal(second_call)
  end

  it 'lazily loads the embedded object only on first access' do
    user = User.create!(profile: raw_data)
    user = User.find(user.id)

    expect(user.instance_variable_defined?(:@__assoc_profile)).to be false

    _ = user.profile

    expect(user.instance_variable_defined?(:@__assoc_profile)).to be true
  end

  it 'does not include id if id is blank in embedded' do
    person = User.new(profile: raw_data)
    expect(person.send(:serialized_attributes)['profile'].first).not_to include('id')
  end

  describe 'with store_as / alias support' do
    it 'stores and retrieves using store_as alias' do
      person = AliasUser.new(profile: raw_data)
      person.save!

      loaded = AliasUser.find(person.id)
      expect(loaded.profile.bio).to eq('Software Engineer')

      raw = person.send(:serialized_attributes)
      expect(raw['p']).to be_an(Hash)
      expect(raw['p']['bio']).to eq('Software Engineer')
    end
  end

  describe 'embedded object from embeds_one' do
    subject(:embedded_profile) { user.profile }

    let(:profile) { Profile.new(bio: 'forbidden') }
    let(:user) do
      user = User.new(profile: profile)
      user.save!
      user
    end

    it 'raises when trying to save/save! an embedded document' do
      expect { embedded_profile.save }.to raise_error('Cannot save an embedded document!')
      expect { embedded_profile.save! }.to raise_error('Cannot save! an embedded document!')
    end

    it 'raises when trying to destroy/destroy! an embedded document' do
      expect { embedded_profile.destroy }.to raise_error('Cannot destroy an embedded document!')
      expect { embedded_profile.destroy! }.to raise_error('Cannot destroy an embedded document!')
    end

    it 'raises when trying to update/update_attribute/update_attributes an embedded document' do
      expect { embedded_profile.update(bio: 'new value') }.to raise_error('Cannot update an embedded document!')
      expect { embedded_profile.update_attribute(:bio, 'new value') }.to raise_error('Cannot update_attribute an embedded document!')
      expect { embedded_profile.update_attributes(bio: 'new value') }.to raise_error('Cannot update an embedded document!')
    end

    it 'raises when trying to delete/remove an embedded document' do
      expect { embedded_profile.remove }.to raise_error('Cannot delete an embedded document!')
      expect { embedded_profile.delete }.to raise_error('Cannot delete an embedded document!')
    end

    it 'raises when trying to update_columns an embedded document' do
      expect { embedded_profile.update_columns(bio: 'new value') }.to raise_error('Cannot update_columns an embedded document!')
    end

    it 'raises when trying to reload an embedded document' do
      expect { embedded_profile.reload }.to raise_error('Cannot reload an embedded document!')
    end

    it 'raises when trying to touch an embedded document' do
      expect { embedded_profile.touch }.to raise_error('Cannot touch an embedded document!')
    end
  end

  describe 'recursive embeds_one loop' do
    it 'can embed a single child recursively' do
      child = Node.new(value: 'Child')
      parent = Node.new(value: 'Parent', child: child)

      expect(parent.child).to be_a(Node)
      expect(parent.child.value).to eq('Child')
    end

    it 'does not loop infinitely when serializing recursive structure' do
      root = Node.new(value: 'Root')
      child = Node.new(value: 'Child')
      root.child = child

      expect {
        root.send(:serialized_attributes)
      }.not_to raise_error
    end

    it 'can support multiple nested levels' do
      lvl3 = Node.new(value: 'Level 3')
      lvl2 = Node.new(value: 'Level 2', child: lvl3)
      lvl1 = Node.new(value: 'Level 1', child: lvl2)
      root = Node.new(value: 'Root', child: lvl1)

      expect(root.child.child.child.value).to eq('Level 3')
    end

    it 'can embed nil safely' do
      node = Node.new(value: 'Alone', child: nil)
      expect(node.child).to be_nil
      expect {
        node.send(:serialized_attributes)
      }.not_to raise_error
    end
  end

  it 'reflects embedded assign in serialized attributes' do
    user = User.new(profile: { bio: 'Old Bio' })
    user.profile = Profile.new(bio: 'New Bio')

    serialized = user.send(:serialized_attributes)
    expect(serialized['profile']['bio']).to eq('New Bio')
  end

  it 'does not reflects embedded changes in serialized attributes' do
    user = User.new(profile: { bio: 'Old Bio' })
    user.profile.bio = 'New Bio'

    serialized = user.send(:serialized_attributes)
    expect(serialized['profile']['bio']).not_to eq('New Bio')
  end

  it 'does not mark parent as changed when only embedded is modified (unless tracked)' do
    user = User.create!(profile: { bio: 'Old Bio' })
    user.reload

    expect(user.changed?).to be false

    user.profile.bio = 'New Bio'
    expect(user.changed?).to be false
  end

  it 'invalidates the parent if the embedded is invalid' do
    user = User.new(profile: { bio: nil })
    expect(user.valid?).to be false
    expect(user.errors[:profile]).not_to be_empty
  end

  it 'updates embedded attributes without replacing instance' do
    user = User.new(profile: { bio: 'Initial' })
    original = user.profile
    user.profile = { bio: 'Updated' }

    expect(user.profile).not_to be_nil
    expect(user.profile.bio).to eq('Updated')
    expect(user.profile).not_to equal(original)
  end

  it 'sets the embedded document to nil' do
    user = User.new(profile: { bio: 'Something' })
    user.profile = nil

    expect(user.profile).to be_nil
    expect(user.attributes['profile']).to be_nil
  end

  it 'returns readable inspect for embedded objects' do
    user = User.new(profile: { bio: 'Visible' })
    expect(user.profile.inspect).to include('bio')
  end

  it 'duplicates the embedded object when parent is duped' do
    user = User.new(profile: { bio: 'original' })
    copy = user.dup

    expect(copy.profile).not_to be_nil
    expect(copy.profile.bio).to eq('original')
    expect(copy.profile).not_to equal(user.profile)
  end

  describe 'embeds_one with inheritance' do
    let(:raw_data) { { bio: 'Inherited', title: 'Lead Dev' } }

    it 'instantiates the correct subclass in embedded field' do
      user = InheritedUser.new(profile: raw_data)

      expect(user.profile).to be_a(ExtendedProfile)
      expect(user.profile.bio).to eq('Inherited')
      expect(user.profile.title).to eq('Lead Dev')
    end

    it 'serializes the inherited fields correctly' do
      user = InheritedUser.new(profile: raw_data)
      serialized = user.send(:serialized_attributes)

      expect(serialized['profile']['bio']).to eq('Inherited')
      expect(serialized['profile']['title']).to eq('Lead Dev')
    end

    it 'validates inherited embedded object' do
      user = InheritedUser.new(profile: { title: 'No Bio' }) # bio is required

      expect(user.valid?).to be false
      expect(user.errors[:profile]).not_to be_empty
    end

    it 'raises when trying to save inherited embedded document directly' do
      embedded = ExtendedProfile.new(bio: 'Oops', title: 'CTO')
      embedded.instance_variable_set(:@_embedded, true)

      expect { embedded.save }.to raise_error('Cannot save an embedded document!')
    end

    describe 'embedded registry inheritance with deep duplication' do
      it 'inherits embedded config from parent' do
        expect(ChildModel.embedded.keys).to include(:profile)
        expect(ChildModel.embedded[:profile][:class_name]).to eq(Profile)
      end

      it 'modifying child embedded does not affect parent' do
        ChildModel.embedded[:profile][:class_name] = 'Overridden'
        expect(ParentModel.embedded[:profile][:class_name]).to eq(Profile)
      end
    end
  end
end
