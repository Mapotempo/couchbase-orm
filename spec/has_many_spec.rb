# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

require File.expand_path('support', __dir__)

shared_examples 'has_many example' do |parameter|
  before :all do
    @context = parameter[:context].to_s
    @rating_test_class = Kernel.const_get("Rating#{@context.camelize}Test".classify)
    @object_test_class = Kernel.const_get("Object#{@context.camelize}Test".classify)
    @object_rating_test_class = Kernel.const_get("ObjectRating#{@context.camelize}Test".classify)

    @rating_test_class.ensure_design_document!
    @object_test_class.ensure_design_document!
    @object_rating_test_class.ensure_design_document!

    @rating_test_class.delete_all
    @object_test_class.delete_all
    @object_rating_test_class.delete_all
  end

  after do
    @rating_test_class.delete_all
    @object_test_class.delete_all
    @object_rating_test_class.delete_all
  end

  it 'returns matching results' do
    first = @object_test_class.create! name: :bob
    second = @object_test_class.create! name: :jane

    rate = @rating_test_class.create! rating: :awesome, "object_#{@context}_test": first
    @rating_test_class.create! rating: :bad, "object_#{@context}_test": second
    @rating_test_class.create! rating: :good, "object_#{@context}_test": first

    expect(rate.try("object_#{@context}_test_id")).to eq(first.id)
    expect(@rating_test_class.respond_to?(:"find_by_object_#{@context}_test_id")).to be(true)
    expect(first.respond_to?(:"rating_#{@context}_tests")).to be(true)

    docs = first.try(:"rating_#{@context}_tests").collect(&:rating)

    expect(docs).to contain_exactly(1, 2)

    first.destroy
    expect { @rating_test_class.find rate.id }.to raise_error(Couchbase::Error::DocumentNotFound)
    expect(@rating_test_class.send(:"#{@context}_all").count).to be(1)
  end

  it 'works through a join model' do
    first = @object_test_class.create! name: :bob
    second = @object_test_class.create! name: :jane

    rate1 = @rating_test_class.create! rating: :awesome, "object_#{@context}_test": first
    _rate2 = @rating_test_class.create! rating: :bad, "object_#{@context}_test": second
    _rate3 = @rating_test_class.create! rating: :good, "object_#{@context}_test": first

    ort = @object_rating_test_class.create! "object_#{@context}_test": first, "rating_#{@context}_test": rate1
    @object_rating_test_class.create! "object_#{@context}_test": second, "rating_#{@context}_test": rate1

    expect(ort.try(:"rating_#{@context}_test_id".to_sym)).to eq(rate1.id)
    expect(rate1.respond_to?(:"object_#{@context}_tests")).to be(true)
    docs = rate1.try(:"object_#{@context}_tests").collect(&:name)

    expect(docs).to contain_exactly('bob', 'jane')
  end

  it 'works with new objects not yet saved' do
    existing_object = @object_test_class.create! name: :bob
    expect(existing_object.send(:"rating_#{@context}_tests")).to be_empty

    @rating_test_class.create! rating: :good, "object_#{@context}_test": existing_object

    new_object = @object_test_class.new name: :jane
    expect(new_object.send(:"rating_#{@context}_tests")).to be_empty
  end
end

describe CouchbaseOrm::HasMany do
  context 'with view' do
    class ObjectRatingViewTest < CouchbaseOrm::Base
      join :object_view_test, :rating_view_test
      view :view_all
    end

    class RatingViewTest < CouchbaseOrm::Base
      enum rating: [:awesome, :good, :okay, :bad], default: :okay
      belongs_to :object_view_test

      has_many :object_view_tests, through: :object_rating_view_test
      view :view_all
    end

    class ObjectViewTest < CouchbaseOrm::Base
      attribute :name, type: String
      has_many :rating_view_tests, dependent: :destroy

      view :view_all
    end

    include_examples('has_many example', context: :view)
  end

  context 'with n1ql' do
    class ObjectRatingN1qlTest < CouchbaseOrm::Base
      join :object_n1ql_test, :rating_n1ql_test

      n1ql :n1ql_all
    end

    class RatingN1qlTest < CouchbaseOrm::Base
      enum rating: [:awesome, :good, :okay, :bad], default: :okay
      belongs_to :object_n1ql_test

      has_many :object_n1ql_tests, through: :object_rating_n1ql_test, type: :n1ql

      n1ql :n1ql_all
    end

    class ObjectN1qlTest < CouchbaseOrm::Base
      attribute :name, type: String

      has_many :rating_n1ql_tests, dependent: :destroy, type: :n1ql

      n1ql :n1ql_all
    end

    include_examples('has_many example', context: :n1ql)
  end

  describe 'dependent: :nullify on has_many' do
    context 'with view' do
      class RatingNullifyViewTest < CouchbaseOrm::Base
        enum rating: [:awesome, :good, :okay, :bad], default: :okay
        belongs_to :object_nullify_view_test
        view :view_all
      end

      class ObjectNullifyViewTest < CouchbaseOrm::Base
        attribute :name, type: String
        has_many :rating_nullify_view_tests, dependent: :nullify
        view :view_all
      end

      before :all do
        RatingNullifyViewTest.ensure_design_document!
        ObjectNullifyViewTest.ensure_design_document!
        RatingNullifyViewTest.delete_all
        ObjectNullifyViewTest.delete_all
      end

      after do
        RatingNullifyViewTest.delete_all
        ObjectNullifyViewTest.delete_all
      end

      it 'nullifies the foreign key and does not delete/destroy children' do
        obj = ObjectNullifyViewTest.create! name: :bob
        r1  = RatingNullifyViewTest.create! rating: :good,    object_nullify_view_test: obj
        r2  = RatingNullifyViewTest.create! rating: :awesome, object_nullify_view_test: obj

        expect { obj.destroy }.to change(ObjectNullifyViewTest, :count).by(-1)

        # children still exist
        reloaded_r1 = RatingNullifyViewTest.find(r1.id)
        reloaded_r2 = RatingNullifyViewTest.find(r2.id)
        expect(reloaded_r1).to be_present
        expect(reloaded_r2).to be_present
      end
    end

    context 'with n1ql' do
      class RatingNullifyN1qlTest < CouchbaseOrm::Base
        enum rating: [:awesome, :good, :okay, :bad], default: :okay
        belongs_to :object_nullify_n1ql_test
        n1ql :n1ql_all
      end

      class ObjectNullifyN1qlTest < CouchbaseOrm::Base
        attribute :name, type: String
        has_many :rating_nullify_n1ql_tests, dependent: :nullify, type: :n1ql
        n1ql :n1ql_all
      end

      before :all do
        RatingNullifyN1qlTest.ensure_design_document!
        ObjectNullifyN1qlTest.ensure_design_document!
        RatingNullifyN1qlTest.delete_all
        ObjectNullifyN1qlTest.delete_all
      end

      after do
        RatingNullifyN1qlTest.delete_all
        ObjectNullifyN1qlTest.delete_all
      end

      it 'nullifies the foreign key and does not delete/destroy children' do
        obj = ObjectNullifyN1qlTest.create! name: :jane
        r1  = RatingNullifyN1qlTest.create! rating: :good,    object_nullify_n1ql_test: obj
        r2  = RatingNullifyN1qlTest.create! rating: :awesome, object_nullify_n1ql_test: obj

        expect { obj.destroy }.to change(ObjectNullifyN1qlTest, :count).by(-1)

        # children still exist
        reloaded_r1 = RatingNullifyN1qlTest.find(r1.id)
        reloaded_r2 = RatingNullifyN1qlTest.find(r2.id)
        expect(reloaded_r1).to be_present
        expect(reloaded_r2).to be_present
      end
    end
  end
end
