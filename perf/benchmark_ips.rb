# frozen_string_literal: true

require "benchmark/ips"
require "couchbase-orm"
require "./models"
require "./gc_suite"
require "./indexes"

# Initialization
CouchbaseOrm::Connection.cluster.buckets.flush_bucket(CouchbaseOrm::Connection.bucket.name)
create_indexes()

puts "Seeding data..."

# Seed one person with references
seed_person = Person.create(birth_date: Date.new(1970, 1, 1), title: "Mr. Seed")
10.times { Post.create(title: "Sample post", person: seed_person) }
10.times { Preference.create(name: "Sample preference", persons: [seed_person]) }

puts "Starting Couchbase ORM benchmark..."

suite = GCSuite.new

Benchmark.ips do |bm|
  bm.config(time: 5, warmup: 2, suite: suite)

  puts "\n[ Root Document Benchmarks ]"

  bm.report("#new") { Person.new }

  bm.report("#create") do
    Person.create(birth_date: Date.new(1970, 1, 1))
  end

  bm.report("#each") do
    Person.all.each(&:birth_date)
  end

  bm.report("#find") do
    Person.find(seed_person.id)
  end

  bm.report("#save") do
    p = Person.find(seed_person.id)
    p.title = "Updated Title"
    p.save
  end

  bm.report("#update_attribute") do
    p = Person.find(seed_person.id)
    p.update_attribute(:title, "Updated Attribute")
  end

  puts "\n[ Embedded 1-1 Benchmarks ]"

  bm.report("#assign_name") do |n|
    p = Person.find(seed_person.id)
    p.name = Name.new(given: "Name #{n}")
  end

  puts "\n[ Referenced 1-1 Benchmarks ]"

  bm.report("#assign_game") do |n|
    p = Person.find(seed_person.id)
    p.game = Game.create(name: "Game #{n}")
    p.save
  end

  puts "\n[ Referenced 1-n Benchmarks ]"

  bm.report("#each_post") do
    p = Person.find(seed_person.id)
    p.posts.each { |post| post.title }
  end

  puts "\n[ Referenced n-n Benchmarks ]"

  bm.report("#each_preference") do
    p = Person.find(seed_person.id)
    p.preferences.each(&:name)
  end
end

Person.delete_all
