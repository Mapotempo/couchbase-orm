# frozen_string_literal: true

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end
source 'https://rubygems.org'
gemspec

gem 'benchmark-ips', '~> 2.14'
