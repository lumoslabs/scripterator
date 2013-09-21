# Scripterator
"Helping you scripterate over all the things"

A lightweight script harness and DSL for iterating over and running operations on ActiveRecord model records, with Redis hooks for managing subsets, failures, and retries.

## Installation

Add this line to your application's Gemfile:

    gem 'scripterator'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install scripterator

## Usage

Create a .rb file with your script code:
```ruby
require 'scripterator'

Scripterator.run "Convert users from legacy auth data" do

  before do
    User.skip_some_callbacks_we_want_to_avoid_during_script_running
  end

  for_each_user do |user|
    user.do_legacy_conversion
  end

  after do
    # some code to run after everything's finished
  end

end
```

Run your script for a given set of IDs:

    $ START=10000 END=19999 bundle exec rails runner my_script.rb >out.txt

Retrieve set information about checked and failed records:

```
> Scripterator.failed_ids_for "Convert users from legacy auth data"
=> [14011, 15634, 17301, 17302]

> Scripterator.already_run_for?("Convert users from legacy auth data", 15000)
=> true
```

User-definable blocks:

Required:

- `for_each_(.+)`: code to run for every record

Optional:

- `model`: code with which model should be loaded, e.g., `model { User.includes(:profile, :roles) }`; if this block is not supplied, the model class is inferred from the `for_each_*` block, e.g., `for_each_post_comment` will cause the model `PostComment` to be loaded
- `before`: code to run before iteration begins
- `after`: code to run after iteration finishes

Environment variable options:

- `START`: first model ID to scripterate
- `END`: last model ID to scripterate
- `REDIS_EXPIRATION`: amount of time (in seconds) before Redis result sets (checked IDs and failed IDs) are expired

Either a starting or and ending ID must be provided.

## Running tests

    $ bundle exec rspec

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
