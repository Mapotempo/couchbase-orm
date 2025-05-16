# frozen_string_literal: true
# rubocop:todo all

require "benchmark/ips"
require "couchbase-orm"
require "./models"
require "./gc_suite"
require "./indexes"

# Initialisation
CouchbaseOrm::Connection.cluster.buckets.flush_bucket(CouchbaseOrm::Connection.bucket.name)
create_indexes()

puts "Starting Couchbase ORM benchmark..."

suite = GCSuite.new

def person
  @person ||= Person.all.last
end

def post
  @post ||= person.posts.last
end

def preference
  @preference ||= person.preferences.last
end

def address
  @address ||= person.addresses.last
end

def person_post_id
  post.id
end

def preference_id
  preference.id
end

def address_id
  address.id
end

def addresses
  Array.new(10_000) do |n|
    Address.new(
      street: "Rue #{n}",
      city: "Paris",
      post_code: "750#{n % 10}"
    )
  end
end

def posts
  Array.new(10_000) { |n| Post.new(title: "Post #{n}") }
end

def preferences
  Array.new(10_000) { |n| Preference.new(name: "Preference #{n}") }
end

Benchmark.ips do |bm|
  bm.config(time: 5, warmup: 2, suite: suite)

  puts "\n[ Root Document Benchmarks ]"

  bm.report("#new") do
    Person.new
  end

  bm.report("#create") do
    Person.create(birth_date: Date.new(1970, 1, 1))
  end

  bm.report("#each") do
    Person.all.each(&:birth_date)
  end

  bm.report("#find") do
    Person.find(Person.all.first.id)
  end

  bm.report("#save") do
    Person.all.each do |p|
      p.title = "Test"
      p.save
    end
  end

  bm.report("#update_attribute") do
    Person.all.each { |p| p.update_attribute(:title, "Updated") }
  end

  puts "\n[ Embedded 1-1 Benchmarks ]"

  bm.report("#relation=") do |n|
    person.name = Name.new(given: "Name #{n}")
  end

  puts "\n[ Referenced 1-1 Benchmarks ]"

  bm.report("#relation=") do |n|
    person.game = Game.new(name: "FF #{n}")
  end

  puts "\n[ Referenced n-n Benchmarks ]"
 
  bm.report("#each") { person.preferences.each(&:name) }

  bm.report("#delete_all") { Person.delete_all }
end
