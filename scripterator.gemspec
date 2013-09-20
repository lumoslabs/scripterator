# -*- encoding: utf-8 -*-
require File.expand_path('../lib/scripterator/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Ted Dumitrescu"]
  gem.email         = ["ted@lumoslabs.com"]
  gem.description   = %q{Script iterator for ActiveRecord models}
  gem.summary       = %q{DSL for running operations on each of a set of models}
  gem.homepage      = "http://lumosity.com"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(spec)/})
  gem.name          = "scripterator"
  gem.require_paths = ["lib"]
  gem.version       = Scripterator::VERSION

  gem.add_development_dependency "rspec", "~> 2.13"
end
