# frozen_string_literal: true

require File.expand_path('support', __dir__)

require 'active_model'

class TypeArrayTest < CouchbaseOrm::Base
  attribute :name
  attribute :tags, :array, type: :string
  attribute :milestones, :array, type: :date
  attribute :flags, :array, type: :boolean
  attribute :things
end

describe CouchbaseOrm::Base do
  it 'is able to store and retrieve an array of strings' do
    obj = TypeArrayTest.new
    obj.tags = ['foo', 'bar']
    obj.save!

    obj = TypeArrayTest.find(obj.id)
    expect(obj.tags).to eq ['foo', 'bar']
  end

  it 'is able to store and retrieve an array of date' do
    dates = [Date.today, Date.today + 1]
    obj = TypeArrayTest.new
    obj.milestones = dates
    obj.save!

    obj = TypeArrayTest.find(obj.id)
    expect(obj.milestones).to eq dates
  end

  it 'is able to store and retrieve an array of boolean' do
    flags = [true, false]
    obj = TypeArrayTest.new
    obj.flags = flags
    obj.save!

    obj = TypeArrayTest.find(obj.id)
    expect(obj.flags).to eq flags
  end

  it 'is able to store and retrieve an array of basic objects' do
    things = [1, '1234', {'key' => 4}]
    obj = TypeArrayTest.new
    obj.things = things
    obj.save!

    obj = TypeArrayTest.find(obj.id)
    expect(obj.things).to eq things
  end
end
