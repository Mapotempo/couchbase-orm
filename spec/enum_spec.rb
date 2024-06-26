# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

require File.expand_path('support', __dir__)

class EnumTest < CouchbaseOrm::Base
  enum rating: [:awesome, :good, :okay, :bad], default: :okay
  enum color: [:red, :green, :blue]
end

describe CouchbaseOrm::Base do
  it 'creates an attribute' do
    base = EnumTest.create!(rating: :good, color: :red)
    expect(base.attribute_names).to eq(['id', 'rating', 'color'])
  end

  it 'sets the attribute' do
    base = EnumTest.create!(rating: :good, color: :red)
    expect(base.rating).not_to be_nil
    expect(base.color).not_to be_nil
  end

  it 'converts it to an int' do
    base = EnumTest.create!(rating: :good, color: :red)
    expect(base.rating).to eq 2
    expect(base.color).to eq 1
  end

  it 'uses default value' do
    base = EnumTest.create!
    expect(base.rating).to eq 3
    expect(base.color).to eq 1
  end
end
