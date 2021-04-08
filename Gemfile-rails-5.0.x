source 'https://rubygems.org'

gemspec

gem 'activerecord', '< 5.1'

group :test, :development do
  gem 'sqlite3'
end
