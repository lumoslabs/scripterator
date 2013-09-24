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

Works with ActiveRecord 3.* (Rails 4 support coming).

## Usage

Create a .rb file with your script code:
```ruby
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

This will produce output of the form:

```
Starting at 2013-09-24 14:53:39 -0700...
2013-09-24 14:53:40 -0700: Checked 0 rows, 0 migrated.
2013-09-24 14:53:41 -0700: Checked 10000 rows, 10000 migrated.
2013-09-24 14:53:41 -0700: Checked 20000 rows, 20000 migrated.
2013-09-24 14:53:42 -0700: Checked 30000 rows, 30000 migrated.
done
Finished at 2013-09-24 14:53:43 -0700...

Total rows migrated: 34903 / 34903
0 rows previously migrated and skipped
0 errors
```

Retrieve set information about checked and failed records:

```
> Scripterator.failed_ids_for "Convert users from legacy auth data"
=> [14011, 15634, 17301, 17302]

> Scripterator.already_run_for?("Convert users from legacy auth data", 15000)
=> true
```

User-definable blocks:

Required:

- `for_each_(.+)`: code to run for every record. This block should return `true` (or a truthy value) if the operation ran successfully, or `false` (or a falsy value) if the record was skipped/ineligible. Errors and Exceptions will be caught by Scripterator and tabulated/output.

Optional:

- `model`: code with which model should be loaded, e.g., `model { User.includes(:profile, :roles) }`; if this block is not supplied, the model class is inferred from the `for_each_*` block, e.g., `for_each_post_comment` will cause the model `PostComment` to be loaded
- `before`: code to run before iteration begins
- `after`: code to run after iteration finishes

Environment variable options:

- `START`: first model ID to scripterate
- `END`: last model ID to scripterate
- `REDIS_EXPIRATION`: amount of time (in seconds) before Redis result sets (checked IDs and failed IDs) are expired

Either a starting or an ending ID must be provided.

## Configuration

Within an optional Rails initializer, configure Scripterator further as follows (`config/initializers/scripterator.rb`):

```ruby
Scripterator.configure do |config|
  # alternate Redis instance
  config.redis = MyRedis.new

  # turn off Redis
  config.redis = nil

  # change default Redis set expiration time
  config.redis_expiration = 5.days

  # set redis_expiration to 0 to turn off expiration
  config.redis_expiration = 0
end
```

## Running tests

    $ bundle exec rspec

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
