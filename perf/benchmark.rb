# frozen_string_literal: true

require 'benchmark'
require 'couchbase-orm'
require './models'
require './indexes'

CouchbaseOrm::Connection.cluster.buckets.flush_bucket(CouchbaseOrm::Connection.bucket.name)
create_indexes()

puts "Starting benchmark for Couchbase ORM"

Benchmark.bm do |bm|
  puts "\n[ Root Document Benchmark ]"

  [ 100000 ].each do |i|
    puts " [ #{i} ]"

    bm.report("#new              ") do
      i.times do
        Person.new
      end
    end

    bm.report("#create           ") do
      i.times do |n|
        Person.create(birth_date: Date.new(1970, 1, 1))
      end
    end

    bm.report("#each             ") do
      Person.all.each { |person| person.birth_date }
    end

    bm.report("#attributes") do
      Person.all.each(&:attributes)
    end

    first_id = Person.all.first.id
    bm.report("#find             ") do
      Person.find(first_id)
    end

    bm.report("#save             ") do
      Person.all.each do |person|
        person.title = "Testing"
        person.save
      end
    end

    bm.report("#update_attribute ") do
      Person.all.each { |person| person.update_attribute(:title, "Updated") }
    end

    Person.delete_all

    GC.start
  end

  Person.delete_all
  Preference.delete_all

  [ 10000 ].each do |i|

    GC.start

    i.times do |n|
      Person.create(title: "#{n}").tap do |person|
        Post.create(title: "#{n}", person: person)
        Preference.create(name: "#{n}", persons: [person])
      end
    end

    puts "\n[ Referenced 1-n Benchmarks ]"

    bm.report("#each [ normal ] ") do
      Post.all.each do |post|
        post.person.title
      end
    end

    puts "\n[ Query N1QL 1-n Benchmarks ]"

    bm.report("#each [ normal ] ") do
      Person.all.each do |person|
        person.posts.each { |post| post.title }
      end
    end

    puts "\n[ Referenced n-n Benchmarks ]"

    bm.report("#each [ normal ] ") do
      Person.all.each do |person|
        person.preferences.each { |preference| preference.name }
      end
    end
  end
end
