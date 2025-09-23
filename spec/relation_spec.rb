# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

require File.expand_path('support', __dir__)

class NestedRelationModel < CouchbaseOrm::NestedDocument
  attribute :name, :string
  attribute :age, :integer
end

class PathRelationModel < CouchbaseOrm::NestedDocument
  attribute :pathelement, :nested, type: PathRelationModel
  attribute :children, :array, type: NestedRelationModel
end

class RelationModel < CouchbaseOrm::Base
  attribute :name, :string
  attribute :last_name, :string
  attribute :active, :boolean
  attribute :age, :integer
  attribute :children, :array, type: NestedRelationModel
  attribute :pathelement, :nested, type: PathRelationModel
  def self.adult
    where(age: {_gte: 18})
  end

  def self.active
    where(active: true)
  end
end

describe CouchbaseOrm::Relation do
  before do
    RelationModel.delete_all
    CouchbaseOrm.logger.debug 'Cleaned before tests'
  end

  after(:all) do
    CouchbaseOrm.logger.debug 'Cleanup after all tests'
    RelationModel.delete_all
  end

  it 'returns a relation' do
    expect(RelationModel.all).to be_a(CouchbaseOrm::Relation::CouchbaseOrm_Relation)
  end

  it 'queries with conditions' do
    RelationModel.create! name: :bob, active: true, age: 10
    RelationModel.create! name: :alice, active: true, age: 20
    RelationModel.create! name: :john, active: false, age: 30
    expect(RelationModel.where(active: true).count).to eq(2)
    expect(RelationModel.where(active: true).size).to eq(2)

    expect(RelationModel.where(active: true).to_a.map(&:name)).to match_array(%w[bob alice])
    expect(RelationModel.where(active: true).where(age: 10).to_a.map(&:name)).to match_array(%w[bob])
  end

  it 'queries with merged conditions' do
    RelationModel.create! name: :bob, active: true, age: 10
    RelationModel.create! name: :bob, active: false, age: 10
    RelationModel.create! name: :alice, active: true, age: 20
    RelationModel.create! name: :john, active: false, age: 30

    expect(RelationModel.where(active: true).where(name: 'bob').count).to eq(1)
  end

  it 'find_bies conditions' do
    RelationModel.create! name: :bob, active: true, age: 10
    m = RelationModel.create! name: :bob, active: false, age: 10
    RelationModel.create! name: :alice, active: true, age: 20
    RelationModel.create! name: :alice, active: false, age: 20

    expect(RelationModel.where(name: 'bob').find_by(active: false)).to eq(m)
    expect(RelationModel.find_by(name: 'bob', active: false)).to eq(m)
  end

  it 'counts without loading models' do
    RelationModel.create! name: :bob, active: true, age: 10
    RelationModel.create! name: :alice, active: false, age: 20

    expect(RelationModel).not_to receive(:find)

    expect(RelationModel.where(active: true).count).to eq(1)
  end

  it 'delete_alls' do
    RelationModel.create!
    RelationModel.create!
    RelationModel.delete_all
    expect(RelationModel.ids).to be_empty
  end

  it 'delete_alls with conditions' do
    RelationModel.create!
    jane = RelationModel.create! name: 'Jane'
    RelationModel.where(name: nil).delete_all
    expect(RelationModel.ids).to contain_exactly(jane.id)
  end

  it 'queries ids' do
    expect(RelationModel.ids).to be_empty
    m1 = RelationModel.create!
    m2 = RelationModel.create!
    expect(RelationModel.ids).to contain_exactly(m1.id, m2.id)
  end

  it 'queries ids with conditions' do
    m1 = RelationModel.create!(active: true, name: 'Jane')
    _m2 = RelationModel.create!(active: false, name: 'Bob')
    _m3 = RelationModel.create!(active: false, name: 'Jane')
    expect(RelationModel.where(active: true, name: 'Jane').ids).to contain_exactly(m1.id)
  end

  it 'queries ids with conditions and limit' do
    RelationModel.create!(active: true, name: 'Jane', age: 2)
    RelationModel.create!(active: false, name: 'Bob', age: 3)
    m = RelationModel.create!(active: true, name: 'Jane', age: 1)
    RelationModel.create!(active: false, name: 'Jane', age: 0)

    expect(RelationModel.where(active: true, name: 'Jane').order(:age).limit(1).ids).to contain_exactly(m.id)
    expect(RelationModel.limit(1).where(active: true, name: 'Jane').order(:age).ids).to contain_exactly(m.id)
  end

  it 'queries ids with order' do
    m1 = RelationModel.create!(age: 10, name: 'b')
    m2 = RelationModel.create!(age: 20, name: 'a')
    expect(RelationModel.order(age: :desc).ids).to contain_exactly(m2.id, m1.id)
    expect(RelationModel.order(age: :asc).ids).to contain_exactly(m1.id, m2.id)
    expect(RelationModel.order(name: :desc).ids).to contain_exactly(m1.id, m2.id)
    expect(RelationModel.order(name: :asc).ids).to contain_exactly(m2.id, m1.id)
    expect(RelationModel.order(:name).ids).to contain_exactly(m2.id, m1.id)
    expect(RelationModel.order(:age).ids).to contain_exactly(m1.id, m2.id)
  end

  it 'queries with list order' do
    m1 = RelationModel.create!(age: 20, name: 'b')
    m2 = RelationModel.create!(age: 5, name: 'a')
    m3 = RelationModel.create!(age: 20, name: 'a')
    expect(RelationModel.order(:age, :name).ids).to contain_exactly(m2.id, m3.id, m1.id)
  end

  it 'queries with chained order' do
    m1 = RelationModel.create!(age: 10, name: 'b')
    m2 = RelationModel.create!(age: 20, name: 'a')
    m3 = RelationModel.create!(age: 20, name: 'c')
    expect(RelationModel.order(age: :desc).order(name: :asc).ids).to contain_exactly(m2.id, m3.id, m1.id)
  end

  it 'queries with order chained with list' do
    m1 = RelationModel.create!(age: 20, name: 'b')
    m2 = RelationModel.create!(age: 5, name: 'a')
    m3 = RelationModel.create!(age: 20, name: 'a', last_name: 'c')
    m4 = RelationModel.create!(age: 20, name: 'a', last_name: 'a')
    expect(RelationModel.order(:age, :name).order(:last_name).ids).to contain_exactly(m2.id, m4.id, m3.id, m1.id)
  end

  it 'queries all' do
    m1 = RelationModel.create!(active: true)
    m2 = RelationModel.create!(active: false)
    expect(RelationModel.all).to contain_exactly(m1, m2)
  end

  it 'queries all with condition and order' do
    m1 = RelationModel.create!(active: true, age: 10)
    m2 = RelationModel.create!(active: true, age: 20)
    _m3 = RelationModel.create!(active: false, age: 30)
    expect(RelationModel.where(active: true).order(age: :desc).all.to_a).to eq([m2, m1])
    expect(RelationModel.all.where(active: true).order(age: :asc).to_a).to eq([m1, m2])
  end

  it 'queries by id' do
    m1 = RelationModel.create!(active: true, age: 10)
    m2 = RelationModel.create!(active: true, age: 20)
    _m3 = RelationModel.create!(active: false, age: 30)
    expect(RelationModel.where(id: [m1.id, m2.id])).to contain_exactly(m1, m2)
  end

  it 'queries first' do
    _m1 = RelationModel.create!(active: true, age: 10)
    m2 = RelationModel.create!(active: true, age: 20)
    _m3 = RelationModel.create!(active: false, age: 30)
    expect(RelationModel.where(active: true).order(age: :desc).first).to eq m2
  end

  it 'queries array first' do
    _m1 = RelationModel.create!(active: true, age: 10)
    m2 = RelationModel.create!(active: true, age: 20)
    _m3 = RelationModel.create!(active: false, age: 30)
    expect(RelationModel.where(active: true).order(age: :desc)[0]).to eq m2
  end

  it 'queries last' do
    _m1 = RelationModel.create!(active: true, age: 10)
    m2 = RelationModel.create!(active: true, age: 20)
    _m3 = RelationModel.create!(active: false, age: 30)
    expect(RelationModel.where(active: true).order(age: :asc).last).to eq m2
  end

  it 'returns a relation when using not' do
    expect(RelationModel.not(active: true)).to be_a(CouchbaseOrm::Relation::CouchbaseOrm_Relation)
    expect(RelationModel.all.not(active: true)).to be_a(CouchbaseOrm::Relation::CouchbaseOrm_Relation)
  end

  it 'has a to_ary method' do
    expect(RelationModel.not(active: true)).to respond_to(:to_ary)
    expect(RelationModel.all.not(active: true)).to respond_to(:to_ary)
  end

  it 'has a each method' do
    expect(RelationModel.not(active: true)).to respond_to(:each)
    expect(RelationModel.all.not(active: true)).to respond_to(:each)
  end

  it 'plucks one element' do
    _m1 = RelationModel.create!(active: true, age: 10)
    _m2 = RelationModel.create!(active: true, age: 20)
    _m3 = RelationModel.create!(active: false, age: 30)
    expect(RelationModel.order(:age).pluck(:age)).to contain_exactly(10, 20, 30)
  end

  it 'finds one element' do
    _m1 = RelationModel.create!(active: true, age: 10)
    m2 = RelationModel.create!(active: true, age: 20)
    _m3 = RelationModel.create!(active: false, age: 30)
    expect(RelationModel.all.find do |m|
      m.age == 20
    end).to eq m2
  end

  it 'plucks several elements' do
    _m1 = RelationModel.create!(active: true, age: 10)
    _m2 = RelationModel.create!(active: true, age: 20)
    _m3 = RelationModel.create!(active: false, age: 30)
    expect(RelationModel.order(:age).pluck(:age, :active)).to contain_exactly([10, true], [20, true], [30, false])
  end

  it 'queries true boolean' do
    m1 = RelationModel.create!(active: true)
    _m2 = RelationModel.create!(active: false)
    _m3 = RelationModel.create!(active: nil)
    expect(RelationModel.where(active: true)).to contain_exactly(m1)
  end

  it 'does not query true boolean' do
    _m1 = RelationModel.create!(active: true)
    m2 = RelationModel.create!(active: false)
    _m3 = RelationModel.create!(active: nil)
    expect(RelationModel.not(active: true)).to contain_exactly(m2) # keep ActiveRecord compatibility by not returning _m3
  end

  it 'queries false boolean' do
    _m1 = RelationModel.create!(active: true)
    m2 = RelationModel.create!(active: false)
    _m3 = RelationModel.create!(active: nil)
    expect(RelationModel.where(active: false)).to contain_exactly(m2)
  end

  it 'does not query false boolean' do
    m1 = RelationModel.create!(active: true)
    _m2 = RelationModel.create!(active: false)
    _m3 = RelationModel.create!(active: nil)
    expect(RelationModel.not(active: false)).to contain_exactly(m1) # keep ActiveRecord compatibility by not returning _m3
  end

  it 'queries nil boolean' do
    _m1 = RelationModel.create!(active: true)
    _m2 = RelationModel.create!(active: false)
    m3 = RelationModel.create!(active: nil)
    expect(RelationModel.where(active: nil)).to contain_exactly(m3)
  end

  it 'does not query nil boolean' do
    m1 = RelationModel.create!(active: true)
    m2 = RelationModel.create!(active: false)
    _m3 = RelationModel.create!(active: nil)
    expect(RelationModel.not(active: nil)).to contain_exactly(m1, m2)
  end

  it 'queries nil and false boolean' do
    _m1 = RelationModel.create!(active: true)
    m2 = RelationModel.create!(active: false)
    m3 = RelationModel.create!(active: nil)
    expect(RelationModel.where(active: [false, nil])).to contain_exactly(m2, m3)
  end

  it 'does not query nil and false boolean' do
    m1 = RelationModel.create!(active: true)
    _m2 = RelationModel.create!(active: false)
    _m3 = RelationModel.create!(active: nil)
    expect(RelationModel.not(active: [false, nil])).to contain_exactly(m1)
  end

  it 'queries by string' do
    m1 = RelationModel.create!(age: 20, active: true)
    m2 = RelationModel.create!(age: 10, active: false)
    m3 = RelationModel.create!(age: 20, active: false)

    expect(RelationModel.where('active = true').count).to eq(1)
    expect(RelationModel.where('active = true')).to contain_exactly(m1)
    expect(RelationModel.where('active = false')).to contain_exactly(m2, m3)
    expect(RelationModel.where(age: 20).where('active = false')).to contain_exactly(m3)
    expect(RelationModel.where('active = false').where(age: 20)).to contain_exactly(m3)
  end

  it 'is empty' do
    expect(RelationModel.empty?).to eq(true)
  end

  it 'is not empty with a created model' do
    RelationModel.create!(active: true)
    expect(RelationModel.empty?).to eq(false)
  end

  describe 'operators' do
    it 'queries by gte and lte' do
      _m1 = RelationModel.create!(age: 10)
      m2 = RelationModel.create!(age: 20)
      m3 = RelationModel.create!(age: 30)
      _m4 = RelationModel.create!(age: 40)
      expect(RelationModel.where(age: {_lte: 30, _gt: 10})).to contain_exactly(m2, m3)
    end
  end

  describe 'update_all' do
    it 'updates matching documents' do
      m1 = RelationModel.create!(age: 10)
      m2 = RelationModel.create!(age: 20)
      m3 = RelationModel.create!(age: 30)
      m4 = RelationModel.create!(age: 40)
      RelationModel.where(age: {_lte: 30, _gt: 10}).update_all(age: 50)
      expect(m1.reload.age).to eq(10)
      expect(m2.reload.age).to eq(50)
      expect(m3.reload.age).to eq(50)
      expect(m4.reload.age).to eq(40)
    end

    it 'updates nested attributes with a for clause (when hash style)' do
      m1 = RelationModel.create!(age: 10,
                                 children: [
NestedRelationModel.new(age: 10, name: 'Tom'), NestedRelationModel.new(age: 20, name: 'Jerry')
])
      m2 = RelationModel.create!(age: 20,
                                 children: [
NestedRelationModel.new(age: 15, name: 'Tom'), NestedRelationModel.new(age: 20, name: 'Jerry')
])
      m3 = RelationModel.create!(age: 20,
                                 children: [
NestedRelationModel.new(age: 10, name: 'Tom'), NestedRelationModel.new(age: 20, name: 'Jerry')
])

      RelationModel.where(age: 20).update_all(child: {age: 50, _for: :children, _when: {child: {name: 'Tom'}}})

      expect(m1.reload.children.map(&:age)).to eq([10, 20])
      expect(m2.reload.children.map(&:age)).to eq([50, 20])
      expect(m3.reload.children.map(&:age)).to eq([50, 20])
    end

    it 'updates nested attributes with a for clause (when path style)' do
      m1 = RelationModel.create!(age: 10,
                                 children: [
NestedRelationModel.new(age: 10, name: 'Tom'), NestedRelationModel.new(age: 20, name: 'Jerry')
])
      m2 = RelationModel.create!(age: 20,
                                 children: [
NestedRelationModel.new(age: 15, name: 'Tom'), NestedRelationModel.new(age: 20, name: 'Jerry')
])
      m3 = RelationModel.create!(age: 20,
                                 children: [
NestedRelationModel.new(age: 10, name: 'Tom'), NestedRelationModel.new(age: 20, name: 'Jerry')
])

      RelationModel.where(age: 20).update_all(child: {age: 50, _for: :children, _when: {'child.name': 'Tom'}})

      expect(m1.reload.children.map(&:age)).to eq([10, 20])
      expect(m2.reload.children.map(&:age)).to eq([50, 20])
      expect(m3.reload.children.map(&:age)).to eq([50, 20])
    end

    it 'updates nested attributes with a path in a for clause' do
      m1 = RelationModel.create!(
        pathelement: PathRelationModel.new(
          pathelement: PathRelationModel.new(
            children: [NestedRelationModel.new(age: 10, name: 'Tom'), NestedRelationModel.new(age: 20, name: 'Jerry')]
          )
        )
      )

      RelationModel.update_all(child: {age: 50, _for: 'pathelement.pathelement.children', _when: {'child.name': 'Tom'}})

      expect(m1.reload.pathelement.pathelement.children.map(&:age)).to eq([50, 20])
    end
  end

  describe 'scopes' do
    it 'returns block value' do
      RelationModel.create!(active: true)
      RelationModel.create!(active: false)
      count = RelationModel.active.scoping do
        RelationModel.count
      end
      expect(count).to eq 1
    end

    it 'chains scopes' do
      _m1 = RelationModel.create!(age: 10, active: true)
      _m2 = RelationModel.create!(age: 20, active: false)
      m3 = RelationModel.create!(age: 30, active: true)
      m4 = RelationModel.create!(age: 40, active: true)

      expect(RelationModel.all.adult.all.active.all).to contain_exactly(m3, m4)
      expect(RelationModel.where(active: true).adult).to contain_exactly(m3, m4)
    end

    it 'is scoped only in current thread' do
      m1 = RelationModel.create!(active: true)
      m2 = RelationModel.create!(active: false)
      RelationModel.active.scoping do
        expect(RelationModel.all).to contain_exactly(m1)
        Thread.start do
          expect(RelationModel.all).to contain_exactly(m1, m2)
        end.join
      end
    end

    it 'propagates error' do
      expect{
        RelationModel.active.scoping do
          raise 'error'
        end
      }.to raise_error(RuntimeError)
    end

    it 'does not keep scope in case of error' do
      _m1 = RelationModel.create!(age: 10, active: true)
      _m2 = RelationModel.create!(age: 10, active: false)
      _m3 = RelationModel.create!(age: 30, active: true)
      _m3 = RelationModel.create!(age: 30, active: false)
      RelationModel.active.scoping do
        expect(RelationModel.count).to eq 2
        begin
          RelationModel.adult.scoping do
            raise 'error'
          end
        rescue RuntimeError
        end
        expect(RelationModel.count).to eq 2
      end
    end
  end

  describe 'memoization' do
    it 'memoizes records across multiple enumerable calls on the same relation' do
      RelationModel.create!(active: true, age: 10, name: 'a')
      RelationModel.create!(active: true, age: 20, name: 'b')

      rel = RelationModel.where(active: true).order(:age)

      expect(RelationModel).to receive(:find).once.and_call_original

      # First materialization
      ages1 = rel.to_a.map(&:age)
      # Subsequent enumerable calls should NOT trigger another find
      ages2 = rel.map(&:age)
      ages3 = []
      rel.each { |m| ages3 << m.age }

      expect(ages1).to eq([10, 20])
      expect(ages2).to eq([10, 20])
      expect(ages3).to eq([10, 20])
    end

    it 'memoizes when using array indexing after first materialization' do
      RelationModel.create!(active: true, age: 10, name: 'a')
      RelationModel.create!(active: true, age: 20, name: 'b')

      rel = RelationModel.where(active: true).order(:age)

      expect(RelationModel).to receive(:find).once.and_call_original

      first = rel[0]
      second = rel[1]
      again_first = rel[0]

      expect([first.age, second.age, again_first.age]).to eq([10, 20, 10])
    end

    it 'memoizes even if the first call is not to_a (e.g. map first, then each)' do
      RelationModel.create!(active: true, age: 10)
      RelationModel.create!(active: true, age: 20)

      rel = RelationModel.where(active: true).order(:age)

      expect(RelationModel).to receive(:find).once.and_call_original

      # First load via map
      rel.map(&:age)
      # Follow-ups reuse cached array
      rel.each { |_| }
      rel.to_a
    end
  end
end
