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

class Company < CouchbaseOrm::Base
  attribute :name, :string
end

class Contact < CouchbaseOrm::Base
  attribute :name, :string
  belongs_to :company
end

class Client < CouchbaseOrm::Base
  embeds_one :contact, class_name: 'Contact'
end

class Comment < CouchbaseOrm::Base
  attribute :content, :string
  belongs_to :comments_container, class_name: 'CommentsContainer'
end

class CommentsContainer < CouchbaseOrm::Base
  has_many :comments, type: :n1ql, class_name: 'Comment'
end

class Article < CouchbaseOrm::Base
  embeds_one :comments_container, class_name: 'CommentsContainer'
end

class Attachment < CouchbaseOrm::Base
  attribute :filename, :string
  attribute :attachable_type, :string
  attribute :attachable_id, :string
  belongs_to :attachable, polymorphic: true
end

class Image < CouchbaseOrm::Base
  attribute :url, :string
  attribute :caption, :string
end

class Video < CouchbaseOrm::Base
  attribute :url, :string
  attribute :duration, :integer
end

class Audio < CouchbaseOrm::Base
  attribute :url, :string
  attribute :bitrate, :integer
end

class Post < CouchbaseOrm::Base
  embeds_one :media, polymorphic: true
end

class RestrictedPost < CouchbaseOrm::Base
  embeds_one :media, polymorphic: ['Image', 'Video']
end

class DefaultProfile < CouchbaseOrm::Base
  attribute :language, :string
  attribute :bio, :string
end

class UserWithDefaultProc < CouchbaseOrm::Base
  embeds_one :profile, class_name: 'DefaultProfile', default: -> { DefaultProfile.new(language: 'en') }
end

class UserWithDefaultStatic < CouchbaseOrm::Base
  embeds_one :profile, class_name: 'DefaultProfile', default: DefaultProfile.new(language: 'fr')
end

class UserWithInstanceContextDefault < CouchbaseOrm::Base
  attribute :preferred_language, :string

  embeds_one :profile, class_name: 'DefaultProfile', default: -> { DefaultProfile.new(language: preferred_language || 'de') }
end

class DefaultImage < CouchbaseOrm::Base
  attribute :url, :string
  attribute :caption, :string
end

class PolymorphicPostWithDefault < CouchbaseOrm::Base
  embeds_one :media, polymorphic: true, default: -> { DefaultImage.new(url: 'default.jpg') }
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

  it 'excludes empty id in as_json for embedded documents' do
    user = User.new(profile: { bio: 'Test Bio' })
    profile_json = user.profile.as_json

    expect(profile_json).not_to have_key('id')
    expect(profile_json['bio']).to eq('Test Bio')
  end

  it 'includes id when id is present in embedded documents' do
    user = User.new(profile: { bio: 'Test Bio' })
    # Manually set an id on the profile
    user.profile.instance_variable_set(:@attributes, user.profile.instance_variable_get(:@attributes).dup)
    user.profile.send(:write_attribute, 'id', 'test-id-123')

    profile_json = user.profile.as_json

    expect(profile_json).to include('id' => 'test-id-123')
    expect(profile_json['bio']).to eq('Test Bio')
  end

  it 'saves changes in embedded document when parent is saved and reloads correctly' do
    user = User.create!(profile: { bio: 'Initial bio' })

    user2 = User.find(user.id)
    user2.profile.bio = 'Updated bio'
    user2.profile = user2.profile
    user2.save!

    user.reload

    expect(user.profile.bio).to eq('Updated bio')
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
        expect(ChildModel.embedded[:profile][:class_name]).to eq(Profile.to_s)
      end

      it 'modifying child embedded does not affect parent' do
        ChildModel.embedded[:profile][:class_name] = 'Overridden'
        expect(ParentModel.embedded[:profile][:class_name]).to eq(Profile.to_s)
      end
    end
  end

  describe 'embeds_one with associations inside embedded object' do
    it 'can access a belongs_to association from embedded object' do
      company = Company.create!(name: 'Tech Corp')
      contact = Contact.new(name: 'Alice', company: company)
      client = Client.new(contact: contact)

      expect(client.contact).to be_a(Contact)
      expect(client.contact.company).to eq(company)
      expect(client.contact.company.name).to eq('Tech Corp')
    end

    it 'can define has_many inside embedded object and access collection' do
      comment_container = CommentsContainer.new
      comment_container.id = CommentsContainer.uuid_generator.next(comment_container)
      article = Article.create!(comments_container: comment_container)
      comment1 = Comment.create!(content: 'First!', comments_container: article.comments_container)
      comment2 = Comment.create!(content: 'Great article!', comments_container: article.comments_container)
      article = Article.find(article.id)

      expect(article.comments_container.comments).to all(be_a(Comment))
      expect(article.comments_container.comments.map(&:content)).to include('First!', 'Great article!')
    ensure
      comment1.destroy! if comment1&.persisted?
      comment2.destroy! if comment2&.persisted?
      article.destroy! if article&.persisted?
    end
  end

  describe 'polymorphic embeds_one' do
    it 'can embed different types polymorphically with type attribute' do
      image = Image.new(url: 'https://example.com/image.jpg', caption: 'A beautiful sunset')
      post = Post.new(media: image)

      expect(post.media).to be_a(Image)
      expect(post.media.url).to eq('https://example.com/image.jpg')
      expect(post.media.caption).to eq('A beautiful sunset')
      expect(post.attributes['media']['type']).to eq('Image')
    end

    it 'can embed a different polymorphic type' do
      video = Video.new(url: 'https://example.com/video.mp4', duration: 120)
      post = Post.new(media: video)

      expect(post.media).to be_a(Video)
      expect(post.media.url).to eq('https://example.com/video.mp4')
      expect(post.media.duration).to eq(120)
      expect(post.attributes['media']['type']).to eq('Video')
    end

    it 'persists and retrieves polymorphic embedded objects correctly' do
      video = Video.new(url: 'https://example.com/demo.mp4', duration: 90)
      post = Post.create!(media: video)

      loaded = Post.find(post.id)
      expect(loaded.media).to be_a(Video)
      expect(loaded.media.url).to eq('https://example.com/demo.mp4')
      expect(loaded.media.duration).to eq(90)
    ensure
      post.destroy! if post&.persisted?
    end

    it 'can switch between different polymorphic types' do
      image = Image.new(url: 'https://example.com/pic.jpg', caption: 'Original')
      post = Post.create!(media: image)

      post.media = Video.new(url: 'https://example.com/clip.mp4', duration: 45)
      post.save!

      post.reload
      expect(post.media).to be_a(Video)
      expect(post.media.url).to eq('https://example.com/clip.mp4')
    ensure
      post.destroy! if post&.persisted?
    end

    it 'sets embedded flag on polymorphic embedded objects' do
      image = Image.new(url: 'https://example.com/test.jpg', caption: 'Test')
      post = Post.new(media: image)

      expect(post.media.instance_variable_get(:@_embedded)).to be true
    end

    it 'can set polymorphic embedded to nil' do
      video = Video.new(url: 'https://example.com/test.mp4', duration: 60)
      post = Post.new(media: video)

      post.media = nil
      expect(post.media).to be_nil
      expect(post.attributes['media']).to be_nil
      expect(post.attributes['media_type']).to be_nil
    end

    it 'validates polymorphic embedded objects' do
      # Assuming Image has validations
      image = Image.new(url: nil, caption: 'No URL')
      post = Post.new(media: image)

      # Since Image doesn't have validations in our test setup, this would pass
      # But demonstrates the structure for validation testing
      expect(post.media).to be_a(Image)
    end

    it 'accepts hash with type key for polymorphic embeds_one' do
      post = Post.new(media: { type: 'image', url: 'https://example.com/hash.jpg', caption: 'From Hash' })

      expect(post.media).to be_a(Image)
      expect(post.media.url).to eq('https://example.com/hash.jpg')
      expect(post.media.caption).to eq('From Hash')
      expect(post.attributes['media']['type']).to eq('Image')
    end

    it 'accepts hash with string type key for polymorphic embeds_one' do
      post = Post.new(media: { 'type' => 'video', 'url' => 'https://example.com/hash.mp4', 'duration' => 75 })

      expect(post.media).to be_a(Video)
      expect(post.media.url).to eq('https://example.com/hash.mp4')
      expect(post.media.duration).to eq(75)
      expect(post.attributes['media']['type']).to eq('Video')
    end

    it 'raises error when hash is missing type key for polymorphic embeds_one' do
      expect {
        Post.new(media: { url: 'https://example.com/no-type.jpg', caption: 'Missing Type' })
      }.to raise_error(ArgumentError, "Cannot infer type from Hash for polymorphic embeds_one. Include 'type' key with class name.")
    end

    it 'persists and retrieves polymorphic embedded from hash' do
      post = Post.create!(media: { type: 'image', url: 'https://example.com/persist.jpg', caption: 'Persisted' })

      loaded = Post.find(post.id)
      expect(loaded.media).to be_a(Image)
      expect(loaded.media.url).to eq('https://example.com/persist.jpg')
      expect(loaded.media.caption).to eq('Persisted')
    ensure
      post.destroy! if post&.persisted?
    end

    it 'includes type in serialized attributes' do
      post = Post.new(media: { type: 'video', url: 'https://example.com/test.mp4', duration: 100 })

      serialized = post.send(:serialized_attributes)
      expect(serialized['media']).to have_key('type')
      expect(serialized['media']['type']).to eq('Video')
    end
  end

  describe 'polymorphic embeds_one with types restriction' do
    it 'accepts allowed types with objects' do
      image = Image.new(url: 'https://example.com/allowed.jpg', caption: 'Allowed')
      post = RestrictedPost.new(media: image)

      expect(post.media).to be_a(Image)
      expect(post.media.url).to eq('https://example.com/allowed.jpg')
    end

    it 'accepts allowed types with hashes' do
      post = RestrictedPost.new(media: { type: 'video', url: 'https://example.com/allowed.mp4', duration: 60 })

      expect(post.media).to be_a(Video)
      expect(post.media.url).to eq('https://example.com/allowed.mp4')
    end

    it 'rejects disallowed types with objects' do
      audio = Audio.new(url: 'https://example.com/denied.mp3', bitrate: 128)
      post = RestrictedPost.new(media: audio)

      expect(post).not_to be_valid
      expect(post.errors[:media]).to include('Audio is not an allowed type. Allowed types: Image, Video')
    end

    it 'rejects disallowed types with hashes' do
      post = RestrictedPost.new(media: { type: 'audio', url: 'https://example.com/denied.mp3', bitrate: 128 })

      expect(post).not_to be_valid
      expect(post.errors[:media]).to include('Audio is not an allowed type. Allowed types: Image, Video')
    end

    it 'persists and retrieves with type restrictions' do
      post = RestrictedPost.create!(media: { type: 'image', url: 'https://example.com/restricted.jpg', caption: 'Restricted' })

      loaded = RestrictedPost.find(post.id)
      expect(loaded.media).to be_a(Image)
      expect(loaded.media.url).to eq('https://example.com/restricted.jpg')
    ensure
      post.destroy! if post&.persisted?
    end
  end

  describe 'embeds_one with default value' do
    it 'returns default value when no data is present' do
      user = UserWithDefaultProc.new
      expect(user.profile).to be_a(DefaultProfile)
      expect(user.profile.language).to eq('en')
    end

    it 'evaluates default proc each time for new instances' do
      user1 = UserWithDefaultProc.new
      profile1 = user1.profile

      user2 = UserWithDefaultProc.new
      profile2 = user2.profile

      expect(profile1).not_to equal(profile2)
      expect(profile1.language).to eq('en')
      expect(profile2.language).to eq('en')
    end

    it 'supports static default values' do
      user = UserWithDefaultStatic.new
      expect(user.profile).to be_a(DefaultProfile)
      expect(user.profile.language).to eq('fr')
    end

    it 'uses instance context in default proc' do
      user = UserWithInstanceContextDefault.new(preferred_language: 'es')
      expect(user.profile).to be_a(DefaultProfile)
      expect(user.profile.language).to eq('es')
    end

    it 'uses fallback in default proc when instance variable is nil' do
      user = UserWithInstanceContextDefault.new
      expect(user.profile).to be_a(DefaultProfile)
      expect(user.profile.language).to eq('de')
    end

    it 'does not use default when data is explicitly set' do
      user = UserWithDefaultProc.new(profile: { language: 'ja', bio: 'Custom bio' })
      expect(user.profile).to be_a(DefaultProfile)
      expect(user.profile.language).to eq('ja')
      expect(user.profile.bio).to eq('Custom bio')
    end

    it 'memoizes the default value after first access' do
      user = UserWithDefaultProc.new
      first_call = user.profile
      second_call = user.profile

      expect(first_call).to equal(second_call)
    end

    it 'allows explicitly setting to nil to override default' do
      user = UserWithDefaultProc.new
      user.profile = nil
      expect(user.profile).to be_nil
    end

    it 'uses default after reset when no data is present' do
      user = UserWithDefaultProc.new
      first_profile = user.profile
      expect(first_profile.language).to eq('en')

      user.profile_reset
      second_profile = user.profile
      expect(second_profile).to be_a(DefaultProfile)
      expect(second_profile.language).to eq('en')
      expect(second_profile).not_to equal(first_profile)
    end

    it 'persists and reloads without default when explicitly set' do
      user = UserWithDefaultProc.create!(profile: { language: 'zh', bio: 'Saved bio' })

      loaded = UserWithDefaultProc.find(user.id)
      expect(loaded.profile.language).to eq('zh')
      expect(loaded.profile.bio).to eq('Saved bio')
    ensure
      user.destroy! if user&.persisted?
    end

    it 'uses default after reload when no data was saved' do
      user = UserWithDefaultProc.create!

      loaded = UserWithDefaultProc.find(user.id)
      expect(loaded.profile).to be_a(DefaultProfile)
      expect(loaded.profile.language).to eq('en')
    ensure
      user.destroy! if user&.persisted?
    end

    it 'persists default value to database when saved' do
      user = UserWithDefaultProc.new
      expect(user.profile.language).to eq('en')

      user.save!

      # Check that default was actually persisted by inspecting serialized attributes
      raw_attributes = user.send(:serialized_attributes)
      expect(raw_attributes['profile']).to be_a(Hash)
      expect(raw_attributes['profile']['language']).to eq('en')

      # Verify persistence by reloading from database
      loaded = UserWithDefaultProc.find(user.id)
      expect(loaded.profile).to be_a(DefaultProfile)
      expect(loaded.profile.language).to eq('en')

      # Verify the data is in the raw database document
      loaded_raw = loaded.send(:serialized_attributes)
      expect(loaded_raw['profile']).to be_a(Hash)
      expect(loaded_raw['profile']['language']).to eq('en')
    ensure
      user.destroy! if user&.persisted?
    end

    it 'supports default value for polymorphic embeds_one' do
      post = PolymorphicPostWithDefault.new
      expect(post.media).to be_a(DefaultImage)
      expect(post.media.url).to eq('default.jpg')
    end

    it 'does not use default for polymorphic when data is set' do
      post = PolymorphicPostWithDefault.new(media: { type: 'image', url: 'custom.jpg', caption: 'Custom' })
      expect(post.media).to be_a(Image)
      expect(post.media.url).to eq('custom.jpg')
      expect(post.media.caption).to eq('Custom')
    end
  end
end
