# frozen_string_literal: true, encoding: ASCII-8BIT

require File.expand_path("../support", __FILE__)

class BucketTest < CouchbaseOrm::Base
    attribute :name, :job
end

describe CouchbaseOrm::Base do
    it "should return bucket name" do
        name = BucketTest.bucket.name
        expect(name).to eq("default")
    end

    it "should retrieve document from bucket" do
        base = BucketTest.create!(name: 'joe')
        resp = BucketTest.bucket.get(base.id, extended: true)
        expect(resp.key).to eq(base.id)
    end

    it "should retrieve document from bucket" do
        base = BucketTest.create!(name: 'joe')
        resp = BucketTest.bucket.n1ql.select('RAW meta(ui).id').from('default').where('name="joe"').order_by('name DESC')
        expect(resp.to_s).to eq("SELECT RAW meta(ui).id FROM default WHERE name=\"joe\" ORDER BY name DESC ")
    end

    it "should expose functions" do
        functions = [
            :build_index, :create_index, :drop_index, :create_primary_index,
            :drop_primary_index, :grant, :on, :to, :infer, :select, :insert_into,
            :delete_from, :update, :from, :with, :use_keys, :unnest, :join, :where,
            :group_by,
        ]
        resp = BucketTest.bucket.n1ql.methods
        expect(resp).to include(*functions)
    end
end
