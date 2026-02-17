# frozen_string_literal: true

require File.expand_path('support', __dir__)

# Polymorphic embedded test classes
class ImageMedia < CouchbaseOrm::Base
  attribute :url, :string
  attribute :caption, :string
end

class VideoMedia < CouchbaseOrm::Base
  attribute :url, :string
  attribute :duration, :integer
end

class DocumentMedia < CouchbaseOrm::Base
  attribute :filename, :string
  attribute :size, :integer
end

class PostWithMedia < CouchbaseOrm::Base
  attribute :title, :string
  embeds_one :media, polymorphic: true
end

class ArticleWithAttachments < CouchbaseOrm::Base
  attribute :title, :string
  embeds_many :attachments, polymorphic: true
end

class DefaultImageMedia < CouchbaseOrm::Base
  attribute :url, :string
  attribute :caption, :string
end

class PostWithDefaultMedia < CouchbaseOrm::Base
  attribute :title, :string
  embeds_one :media, class_name: 'DefaultImageMedia', default: -> { DefaultImageMedia.new(url: 'https://default.com/image.jpg', caption: 'Default') }
end

class PostWithDefaultMediaHash < CouchbaseOrm::Base
  attribute :title, :string
  embeds_one :media, class_name: 'DefaultImageMedia', default: DefaultImageMedia.new(url: 'https://default.com/hash.jpg', caption: 'Default Hash')
end

class ArticleWithDefaultAttachments < CouchbaseOrm::Base
  attribute :title, :string
  embeds_many :attachments, class_name: 'DefaultImageMedia', default: -> { [DefaultImageMedia.new(url: 'https://default.com/1.jpg', caption: 'Default 1')] }
end

describe CouchbaseOrm::Embedded do
  describe 'polymorphic embeds_one' do
    describe 'serialization' do
      it 'serializes polymorphic embedded object with type' do
        image = ImageMedia.new(url: 'https://example.com/test.jpg', caption: 'Test Image')
        post = PostWithMedia.create!(title: 'My Post', media: image)

        json = JSON.parse(post.to_json)
        expect(json['media']).to include('type' => 'ImageMedia')
        expect(json['media']['url']).to eq('https://example.com/test.jpg')
        expect(json['media']['caption']).to eq('Test Image')
      ensure
        post.destroy if post&.persisted?
      end

      it 'includes polymorphic embedded object in inspect output' do
        video = VideoMedia.new(url: 'https://example.com/video.mp4', duration: 120)
        post = PostWithMedia.create!(title: 'Video Post', media: video)

        inspect_output = post.inspect
        expect(inspect_output).to include('PostWithMedia')
        expect(inspect_output).to include('title: "Video Post"')
      ensure
        post.destroy if post&.persisted?
      end

      it 'supports as_json with polymorphic embedded object' do
        image = ImageMedia.new(url: 'https://example.com/image.jpg', caption: 'Sunset')
        post = PostWithMedia.create!(title: 'As JSON Test', media: image)

        json_hash = post.as_json
        expect(json_hash['media']).to be_a(Hash)
        expect(json_hash['media']['type']).to eq('ImageMedia')
        expect(json_hash['media']['url']).to eq('https://example.com/image.jpg')
      ensure
        post.destroy if post&.persisted?
      end
    end

    describe 'dirty tracking' do
      it 'tracks changes when polymorphic embedded object is modified' do
        image = ImageMedia.new(url: 'https://example.com/pic.jpg', caption: 'Original')
        post = PostWithMedia.create!(title: 'Test', media: image)

        expect(post.changes.empty?).to be(true)

        video = VideoMedia.new(url: 'https://example.com/new.mp4', duration: 60)
        post.media = video

        expect(post.changes.empty?).to be(false)
        expect(post.changed?).to be(true)
        expect(post.changed_attributes.keys).to include('media')
      ensure
        post.destroy if post&.persisted?
      end
    end

    describe 'persistence' do
      it 'persists and loads polymorphic embedded object with correct type' do
        doc = DocumentMedia.new(filename: 'report.pdf', size: 2048)
        post = PostWithMedia.create!(title: 'Document Post', media: doc)

        loaded = PostWithMedia.find(post.id)
        expect(loaded.media).to be_a(DocumentMedia)
        expect(loaded.media.filename).to eq('report.pdf')
        expect(loaded.media.size).to eq(2048)
      ensure
        post.destroy if post&.persisted?
      end

      it 'handles nil polymorphic embedded object' do
        post = PostWithMedia.create!(title: 'No Media')

        expect(post.media).to be_nil
        expect(post.attributes['media']).to be_nil

        loaded = PostWithMedia.find(post.id)
        expect(loaded.media).to be_nil
      ensure
        post.destroy if post&.persisted?
      end
    end
  end

  describe 'polymorphic embeds_many' do
    describe 'serialization' do
      it 'serializes polymorphic embedded collection with types' do
        image = ImageMedia.new(url: 'https://example.com/img.jpg', caption: 'Photo')
        video = VideoMedia.new(url: 'https://example.com/vid.mp4', duration: 90)
        article = ArticleWithAttachments.create!(title: 'Multi-media', attachments: [image, video])

        json = JSON.parse(article.to_json)
        expect(json['attachments']).to be_an(Array)
        expect(json['attachments'].size).to eq(2)
        expect(json['attachments'][0]['type']).to eq('ImageMedia')
        expect(json['attachments'][1]['type']).to eq('VideoMedia')
      ensure
        article.destroy if article&.persisted?
      end

      it 'supports as_json with polymorphic embedded collection' do
        video = VideoMedia.new(url: 'https://example.com/video.mp4', duration: 120)
        doc = DocumentMedia.new(filename: 'doc.pdf', size: 2048)
        article = ArticleWithAttachments.create!(title: 'JSON Test', attachments: [video, doc])

        json_hash = article.as_json
        expect(json_hash['attachments']).to be_an(Array)
        expect(json_hash['attachments'].size).to eq(2)
        expect(json_hash['attachments'][0]['type']).to eq('VideoMedia')
        expect(json_hash['attachments'][1]['type']).to eq('DocumentMedia')
      ensure
        article.destroy if article&.persisted?
      end
    end

    describe 'dirty tracking' do
      it 'tracks changes when polymorphic embedded collection is modified' do
        image = ImageMedia.new(url: 'https://example.com/original.jpg', caption: 'Original')
        article = ArticleWithAttachments.create!(title: 'Test', attachments: [image])

        expect(article.changes.empty?).to be(true)

        video = VideoMedia.new(url: 'https://example.com/new.mp4', duration: 45)
        article.attachments = [image, video]

        expect(article.changed?).to be(true)
      ensure
        article.destroy if article&.persisted?
      end
    end

    describe 'persistence' do
      it 'persists and loads polymorphic embedded collection with correct types' do
        doc = DocumentMedia.new(filename: 'file.pdf', size: 1024)
        image = ImageMedia.new(url: 'https://example.com/pic.jpg', caption: 'Picture')
        article = ArticleWithAttachments.create!(title: 'Mixed Media', attachments: [doc, image])

        loaded = ArticleWithAttachments.find(article.id)
        expect(loaded.attachments.size).to eq(2)
        expect(loaded.attachments[0]).to be_a(DocumentMedia)
        expect(loaded.attachments[0].filename).to eq('file.pdf')
        expect(loaded.attachments[1]).to be_a(ImageMedia)
        expect(loaded.attachments[1].caption).to eq('Picture')
      ensure
        article.destroy if article&.persisted?
      end

      it 'handles empty polymorphic embedded collection' do
        article = ArticleWithAttachments.create!(title: 'No Attachments')

        expect(article.attachments).to eq([])
        expect(article.attributes['attachments']).to eq([])

        loaded = ArticleWithAttachments.find(article.id)
        expect(loaded.attachments).to eq([])
      ensure
        article.destroy if article&.persisted?
      end

      it 'creates polymorphic embedded collection from hash with type key' do
        article = ArticleWithAttachments.create!(
          title: 'From Hash',
          attachments: [
            { type: 'image_media', url: 'https://example.com/hash.jpg', caption: 'From Hash' },
            { type: 'video_media', url: 'https://example.com/hash.mp4', duration: 75 }
          ]
        )

        expect(article.attachments.size).to eq(2)
        expect(article.attachments[0]).to be_a(ImageMedia)
        expect(article.attachments[1]).to be_a(VideoMedia)

        loaded = ArticleWithAttachments.find(article.id)
        expect(loaded.attachments[0].url).to eq('https://example.com/hash.jpg')
        expect(loaded.attachments[1].duration).to eq(75)
      ensure
        article.destroy if article&.persisted?
      end
    end
  end

  describe 'default values for embeds_one' do
    describe 'serialization' do
      it 'includes default embedded object in as_json when not set' do
        post = PostWithDefaultMedia.new(title: 'Test Post')

        json_hash = post.as_json
        expect(json_hash['media']).to be_a(Hash)
        expect(json_hash['media'].keys).to_not include('id')
        expect(json_hash['media'].keys).to_not include('type')
        expect(json_hash['media']['url']).to eq('https://default.com/image.jpg')
        expect(json_hash['media']['caption']).to eq('Default')
      end

      it 'includes default embedded object in to_json when not set' do
        post = PostWithDefaultMedia.new(title: 'Test Post')

        json_hash = JSON.parse(post.to_json)
        expect(json_hash['media']).to be_a(Hash)
        expect(json_hash['media'].keys).to_not include('id')
        expect(json_hash['media'].keys).to_not include('type')
        expect(json_hash['media']['url']).to eq('https://default.com/image.jpg')
        expect(json_hash['media']['caption']).to eq('Default')
      end

      it 'uses actual value if set, not default' do
        custom_media = DefaultImageMedia.new(url: 'https://custom.com/image.jpg', caption: 'Custom')
        post = PostWithDefaultMedia.new(title: 'Test Post', media: custom_media)

        json_hash = post.as_json
        expect(json_hash['media']).to be_a(Hash)
        expect(json_hash['media'].keys).to_not include('id')
        expect(json_hash['media'].keys).to_not include('type')
        expect(json_hash['media']['url']).to eq('https://custom.com/image.jpg')
        expect(json_hash['media']['caption']).to eq('Custom')
      end

      it 'supports non-proc default values' do
        post = PostWithDefaultMediaHash.new(title: 'Test Post')

        json_hash = post.as_json
        expect(json_hash['media']).to be_a(Hash)
        expect(json_hash['media'].keys).to_not include('id')
        expect(json_hash['media'].keys).to_not include('type')
        expect(json_hash['media']['url']).to eq('https://default.com/hash.jpg')
        expect(json_hash['media']['caption']).to eq('Default Hash')
      end
    end
  end

  describe 'default values for embeds_many' do
    describe 'serialization' do
      it 'includes default embedded collection in as_json when not set' do
        article = ArticleWithDefaultAttachments.new(title: 'Test Article')

        json_hash = article.as_json
        expect(json_hash['attachments']).to be_an(Array)
        expect(json_hash['attachments'].size).to eq(1)
        expect(json_hash['attachments'][0].keys).to_not include('id')
        expect(json_hash['attachments'][0].keys).to_not include('type')
        expect(json_hash['attachments'][0]['url']).to eq('https://default.com/1.jpg')
        expect(json_hash['attachments'][0]['caption']).to eq('Default 1')
      end

      it 'includes default embedded collection in to_json when not set' do
        article = ArticleWithDefaultAttachments.new(title: 'Test Article')

        json_hash = JSON.parse(article.to_json)
        expect(json_hash['attachments']).to be_an(Array)
        expect(json_hash['attachments'].size).to eq(1)
        expect(json_hash['attachments'][0].keys).to_not include('id')
        expect(json_hash['attachments'][0].keys).to_not include('type')
        expect(json_hash['attachments'][0]['url']).to eq('https://default.com/1.jpg')
        expect(json_hash['attachments'][0]['caption']).to eq('Default 1')
      end

      it 'uses actual value if set, not default' do
        custom_media = DefaultImageMedia.new(url: 'https://custom.com/image.jpg', caption: 'Custom')
        article = ArticleWithDefaultAttachments.new(title: 'Test Article', attachments: [custom_media])

        json_hash = article.as_json
        expect(json_hash['attachments'].size).to eq(1)
        expect(json_hash['attachments'][0].keys).to_not include('id')
        expect(json_hash['attachments'][0].keys).to_not include('type')
        expect(json_hash['attachments'][0]['url']).to eq('https://custom.com/image.jpg')
        expect(json_hash['attachments'][0]['caption']).to eq('Custom')
      end
    end
  end

  describe 'try_load with polymorphic embedded objects' do
    it 'loads model with polymorphic embeds_one correctly' do
      image = ImageMedia.new(url: 'https://example.com/load.jpg', caption: 'Load Test')
      post = PostWithMedia.create!(title: 'Try Load', media: image)

      loaded = CouchbaseOrm.try_load(post.id)
      expect(loaded).to be_a(PostWithMedia)
      expect(loaded.media).to be_a(ImageMedia)
      expect(loaded.media.url).to eq('https://example.com/load.jpg')
    ensure
      post.destroy if post&.persisted?
    end

    it 'loads model with polymorphic embeds_many correctly' do
      video = VideoMedia.new(url: 'https://example.com/v.mp4', duration: 100)
      doc = DocumentMedia.new(filename: 'test.pdf', size: 512)
      article = ArticleWithAttachments.create!(title: 'Try Load Many', attachments: [video, doc])

      loaded = CouchbaseOrm.try_load(article.id)
      expect(loaded).to be_a(ArticleWithAttachments)
      expect(loaded.attachments.size).to eq(2)
      expect(loaded.attachments[0]).to be_a(VideoMedia)
      expect(loaded.attachments[1]).to be_a(DocumentMedia)
    ensure
      article.destroy if article&.persisted?
    end
  end
end
