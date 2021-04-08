source 'https://rubygems.org'

gemspec

gem 'activerecord', '< 5.0'

group :test, :development do
  gem 'sqlite3'
end

