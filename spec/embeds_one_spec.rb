# frozen_string_literal: true

require File.expand_path('support', __dir__)

class Profile < CouchbaseOrm::Base
  attribute :bio, :string
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

describe CouchbaseOrm::EmbedsOne do
  let(:raw_data) { { bio: 'Software Engineer' } }

  it 'defines an attribute with default empty hash' do
    user = User.new
    expect(user.attributes['profile']).to eq({})
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

    # force re-read
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
    user = User.new(profile: raw_data)

    expect(user.instance_variable_defined?(:@__assoc_profile)).to be false

    _ = user.profile

    expect(user.instance_variable_defined?(:@__assoc_profile)).to be true
  end

  describe 'with store_as / alias support' do
    it 'stores and retrieves using store_as alias' do
      person = AliasUser.new(profile: raw_data)
      person.save!

      # Re-fetch to ensure correct storage and retrieval
      loaded = AliasUser.find(person.id)
      expect(loaded.profile.bio).to eq('Software Engineer')

      # Check raw attribute storage (simulate serialized JSON)
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
end
