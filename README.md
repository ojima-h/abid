# Abid

Abid is a simple Workflow Engine based on Rake.

## Installation

1. Install abid gem.

    Add this line to your application's Gemfile:

    ```ruby
    gem 'abid'
    ```

    And then execute:

        $ bundle

    Or install it yourself as:

        $ gem install abid

    After installed execute:

2. Setup a database.

        $ bundle exec abid db:migrate

## Usage

Abid is an extention of rake, so you can use any rake syntax.

First, you must write a “Abidfile” file which contains the tasks:

```ruby
require 'open-uri'

task default: 'count'

play :fetch_source do
  param :date, type: :date

  def run
    mkdir 'out'
    open('http://example.com') do |f|
      File.write("out/#{date.strftime('%Y-%m-%d')}/example.com", f.read)
    end
  end
end

play :count do
  param :date, type: :date

  setup do
    needs 'fetch_source', date: date
  end

  def run
    puts File.read("out/#{date.strftime('%Y-%m-%d')}/example.com").lines.length
  end
end
```

Then you can invoke the task:

```
$ bundle exec abid count date=2016-01-01
```

This Abidfile has two tasks: `fetch_source` and `count`. They can be treated as a normal rake task, but they have some additional features:

* A play can take parameters. They are declared with `param` keyword, and passed via environment variables.
* All play results are saved to the external database. If a play is invoked twice with same parameters, it will be ignored.
* Depending tasks can be declared in `setup` block. If a depending task is a play task, parameters can be passed.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ojima-h/abid. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
