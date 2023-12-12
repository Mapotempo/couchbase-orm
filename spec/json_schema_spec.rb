# frozen_string_literal: true, encoding: ASCII-8BIT

require File.expand_path("../support", __FILE__)

class JsonSchemaBaseTest < CouchbaseOrm::Base
  attribute :name, :string
  attribute :numb, :integer

  design_document('JsonSchemaBaseTest')
  validate_json_schema
end

class UnknownTest < CouchbaseOrm::Base
  attribute :test, :boolean
  validate_json_schema
end

class EntitySnakecase < CouchbaseOrm::Base
  attribute :value, :string
  validate_json_schema
end

describe CouchbaseOrm::JsonSchema::Loader do

  after(:each) do
    reset_schemas
  end

  context "with validation enabled on model" do

    it "With no existing dir " do
      load_schemas("../dontexist")
      expect(CouchbaseOrm::JsonSchema::Loader.instance.get_json_schema({ :type => "JsonSchemaBaseTest" })).to be_nil
    end

    it "Without existing json " do
      load_schemas("../empty-json-schema")
      expect(CouchbaseOrm::JsonSchema::Loader.instance.get_json_schema({ :type => "JsonSchemaBaseTest" })).to be_nil
    end

    it "with schema " do
      load_schemas("../json-schema")
      expect(CouchbaseOrm::JsonSchema::Loader.instance.get_json_schema({ :type => "JsonSchemaBaseTest" })).to include('"name"')
      expect(CouchbaseOrm::JsonSchema::Loader.instance.get_json_schema({ :type => "Unknown" })).to be_nil

    end
  end

  describe CouchbaseOrm::JsonSchema::Validator do
    after(:each) do
      reset_schemas
    end

    it "creation ok" do
          load_schemas("../json-schema")
      base = EntitySnakecase.create!(value: "value_one")
      base.delete
    end

    it "creation ko" do
      load_schemas("../json-schema")
      expect { EntitySnakecase.create!(value: "value_1") }.to raise_error CouchbaseOrm::JsonSchema::JsonValidationError
    end

    it "update ok" do
      load_schemas("../json-schema")
      base = EntitySnakecase.create!(value: "value_one")
      base.value = "value_two"
      base.save
      base.delete
    end

    it "update ko" do
      load_schemas("../json-schema")
      base = EntitySnakecase.create!(value: "value_one")
      base.value = "value_2"
      expect { base.save }.to raise_error CouchbaseOrm::JsonSchema::JsonValidationError
      base.delete
    end

    it "creation ok with design_document" do
      load_schemas("../json-schema")
      base = JsonSchemaBaseTest.create!(name: "dsdsd", numb: 3)
      base.delete
    end

    it "creation ko with design_document" do
      load_schemas("../json-schema")
      expect { JsonSchemaBaseTest.create!(name: "dsdsd", numb: 2) }.to raise_error CouchbaseOrm::JsonSchema::JsonValidationError
    end

    it "update ok with design_document" do
      load_schemas("../json-schema")
      base = JsonSchemaBaseTest.create!(name: "dsdsd", numb: 3)
      base.numb = 4
      base.save
      base.delete
    end

    it "update ok with design_document" do
      load_schemas("../json-schema")
      base = JsonSchemaBaseTest.create!(name: "dsdsd", numb: 3)
      base.numb = 2
      expect { base.save }.to raise_error CouchbaseOrm::JsonSchema::JsonValidationError
      base.delete
    end

    it "save with entity not define in schema files" do
      load_schemas("../json-schema")
      base = UnknownTest.create!(test: true)
      base.delete
    end

    it "update with entity not define in schema files" do
      load_schemas("../json-schema")
      base = UnknownTest.create!(test: true)
      base.test = false
      base.save
      base.delete
    end
  end

  context "with validation disabled on model" do
    before do
      EntitySnakecase.instance_variable_set(:@json_validation_config, {enabled: false})
    end
    it "does not validate schema (even if scehma exists and is not valid)" do
      load_schemas("../json-schema")
      base = EntitySnakecase.create!(value: "value_one")
      base.value = "value_2"
      expect { base.save }.not_to raise_error CouchbaseOrm::JsonSchema::JsonValidationError
      base.delete
    end

  end
end


# TODO : extract following helpers methods elsewhere

def load_schemas(file_relative_path)
  CouchbaseOrm::JsonSchema::Loader.instance.send(:instance_variable_set, :@schemas_directory, File.expand_path(file_relative_path, __FILE__))
  CouchbaseOrm::JsonSchema::Loader.instance.send(:initialize_schemas)
end

def reset_schemas
  CouchbaseOrm::JsonSchema::Loader.instance.instance_variable_set :@schemas, nil
end
