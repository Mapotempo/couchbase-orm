# frozen_string_literal: true
require 'couchbase-orm'

class Person < CouchbaseOrm::Base

  attribute :first_name, type: String
  attribute :last_name, type: String
  attribute :email, type: String
  attribute :birth_date, type: Date
  attribute :title, type: String

  embeds_one :name, validate: false
  embeds_many :addresses, validate: false

  has_many :posts, type: :n1ql, validate: false
  belongs_to :game, validate: false
  has_and_belongs_to_many :preferences, auto_save: true
end

class Name < CouchbaseOrm::Base

  attribute :given, type: String
  attribute :family, type: String
  attribute :middle, type: String
end

class Address < CouchbaseOrm::Base

  attribute :street, type: String
  attribute :city, type: String
  attribute :state, type: String
  attribute :post_code, type: String
  attribute :address_type, type: String
end

class Post < CouchbaseOrm::Base

  attribute :title, type: String
  attribute :content, type: String
  belongs_to :person
end

class Game < CouchbaseOrm::Base

  attribute :name, type: String
  belongs_to :person
end

class Preference < CouchbaseOrm::Base

  attribute :name, type: String
  has_and_belongs_to_many :persons
end