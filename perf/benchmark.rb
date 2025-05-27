# frozen_string_literal: true

require 'benchmark'
require 'couchbase-orm'
require './models'
require './indexes'

CouchbaseOrm::Connection.cluster.buckets.flush_bucket(CouchbaseOrm::Connection.bucket.name)
create_indexes

# rubocop:disable Metrics/BlockLength
Benchmark.bm do |bm|
  [100000].each do |i|
    bm.report('#new              ') do
      i.times do
        Person.new
      end
    end

    bm.report('#create           ') do
      i.times do |_n|
        Person.create(birth_date: Date.new(1970, 1, 1))
      end
    end

    bm.report('#each             ') do
      Person.all.each(&:birth_date)
    end

    bm.report('#attributes') do
      Person.all.each(&:attributes)
    end

    first_id = Person.all.first.id
    bm.report('#find             ') do
      Person.find(first_id)
    end

    bm.report('#save             ') do
      Person.all.each do |person|
        person.title = 'Testing'
        person.save
      end
    end

    bm.report('#update_attribute ') do
      Person.all.each { |person| person.update_attribute(:title, 'Updated') }
    end

    Person.delete_all

    GC.start
  end

  Person.delete_all
  Preference.delete_all

  [10000].each do |i|
    GC.start

    i.times do |n|
      Person.create(title: n.to_s).tap do |person|
        Post.create(title: n.to_s, person: person)
        Preference.create(name: n.to_s, persons: [person])
      end
    end

    bm.report('#belong_to [ normal ] ') do
      Post.all.each do |post|
        post.person.title
      end
    end

    bm.report('#has_many [ normal ] ') do
      Person.all.each do |person|
        person.posts.each(&:title)
      end
    end

    bm.report('#has_and_belong_to [ normal ] ') do
      Person.all.each do |person|
        person.preferences.each(&:name)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
