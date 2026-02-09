# frozen_string_literal: true

require File.expand_path('lib/couchbase-orm/version', __dir__)

Gem::Specification.new do |gem|
  gem.name = 'couchbase-orm'
  gem.version       = CouchbaseOrm::VERSION
  gem.license       = 'MIT'
  gem.authors       = ['Stephen von Takach']
  gem.email         = ['steve@cotag.me']
  gem.homepage      = 'https://github.com/cotag/couchbase-orm'
  gem.summary       = 'Couchbase ORM for Rails'
  gem.description   = 'A Couchbase ORM for Rails'

  gem.required_ruby_version = '>= 3.0'
  gem.require_paths = ['lib']

  gem.add_runtime_dependency     'activemodel',   ENV['ACTIVE_MODEL_VERSION'] || '>= 6.1.7.7', '< 7.1'
  gem.add_runtime_dependency     'activerecord',  ENV['ACTIVE_MODEL_VERSION'] || '>= 6.1.7.7', '< 7.1'

  gem.add_runtime_dependency     'couchbase',    '~> 3.4.5'
  gem.add_runtime_dependency     'radix',        '~> 2.2' # converting numbers to and from any base

  gem.add_development_dependency 'actionpack', ENV['ACTIVE_MODEL_VERSION'] || '>= 6.1.7.7', '< 7.1'
  gem.add_development_dependency 'base64'
  gem.add_development_dependency 'mapotempo_rubocop', '<1.0'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'pry-stack_explorer'
  gem.add_development_dependency 'rake', '~> 12.2'
  gem.add_development_dependency 'rspec', '~> 3.7'
  gem.add_development_dependency 'rubocop-rake', '<1.0'
  gem.add_development_dependency 'rubocop-rspec', '~>3.0'
  gem.add_development_dependency 'simplecov'
  gem.add_development_dependency 'timecop'
  gem.add_development_dependency 'yard', '~> 0.9'

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
end
