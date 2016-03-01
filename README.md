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
    open('http://example.com') do |f|
      FileUtils.makedirs "out/#{date.strftime('%Y-%m-%d')}"
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

This Abidfile has two tasks: `fetch_source` and `count`. They are kinds of rake tasks, but they have some additional features:

* A play can take parameters. They are declared with `param` keyword, and passed via environment variables.
* All play results are saved to the external database. If a play is invoked twice with same parameters, it will be ignored.
* Depending tasks can be declared in `setup` block. If a depending task is a play task, parameters can be specified.


## Execution Model

When a play is invoked, its parameters and results are saved in a database by default.
If the play has been executed with same parameters and successed, it will not be executed any more.

```ruby
# Abidfile.rb
play :test do
  params :name, type: :string
  def run
    puts name
  end
end

$ abid test name=apple #=> "apple"
$ abid test name=apple # nothing happens
$ abid test name=orange #=> "orange"
```

Normal rake task results are not stored in DB.
They are always executed even if they have been executed and successed.
These tasks are called "volatile".

If prerequisites tasks have been failed, the subsequent task also fails.
When prerequisites failed, you have to manually fix a problem and re-execute them.

```ruby
# Abidfile.rb
play :query do
  def run
    result = `mysql -e 'SELECT COUNT(*) FROM users'`
    File.write(result, 'result.txt')
  end
end
play :report do
  setup { needs :query }
  def run
    `cat result.txt | sendmail all@example.com`
  end
end

$ abid query   #=> Failed because of MySQL server down
$ abid report  #=> Fails because prerequisites failed
$ ...          # restart MySQL server
$ abid query   #=> ok
$ abid report  #=> ok

```

### Volatile plays

Abid plays can also be volatile.

```
play :voaltile_play do
  set :volatile, true
  def run
    ...
  end
end
```

These plays are not stored in DB and will be always executed.

### Repair mode

When abid is executed with `--repair` flag, failed prerequisites are re-executed and successed tasks are executed only when their prerequisites are executed.

```
$ abid report           #=> Failed because of MySQL server down
$ ...                   # restart MySQL server
$ abid --repair report  #=> :query and :report tasks are executed
```

### Parallel execution

All tasks are executed in a thread pool.

By default, the thread pool size is 1, i.e. all tasks are executed in single thread. When `-m` option is given, the thread pool size is decided from CPU size. You can specify the thread pool size by `-j` option.

Abid supports multiple thread pools.
Each tasks can be executed in different thread pools.

```ruby
define_worker :copy, 2
define_worker :hive, 4

play :copy_source_1 do
  set :worker, :copy
  def run
    ...
  end
end

play :hive_query_1 do
  set :worker, :hive
  def run
    ...
  end
end
```

Two thread pools `copy` and `hive` are defined in above example, each thread pool sizes are 2 and 4.
`:copy_source_1` is executed in `copy` thread pool, and `:hive_query_1` is executed in `hive` thread pool.

## Plays detail

### Params

```ruby
play :sample do
  param :name, type: :string
  param :date, type: :date, default: Date.today - 1

  def run
    date #=> #<Date: ????-??-?? ((0000000j,0s,0n),+0s,0000000j)>
  end
end
```

Each parameters are initialized by corresponding environment variables. If no environment variable with same name is found, default will be used.

Abid supports following types:

- `boolean`
- `int`
- `float`
- `string`
- `date`
- `datetime`
- `time`

### Settings

```ruby
play :count do
  set(:file_path, './sql/count.sql')
  set(:query) { File.read(file_path) }

  def run
    query #=> the contents of './sql/count.sql'
  end
end
```

Plays settings can be declared by `set` and referenced in `run` method.
If block given, it is evaluated in the same context as `run` method.
The block is called only once and its result is cached.

Following settings are used in abid core:
- `worker`
- `volatile`

### Dependencies

```ruby
play :sample do
  param :name, type: :string  
  setup do
    needs "parent_task:#{name}"
  end

  def run
    # executed after `parent_task`
  end
end
```

All prerequisites must be declared in `setup` block.
You can refer parameters and settings in `setup` block.

### Callbacks

```ruby
play :sample do
  def run
    ...
  end

  before do
    # executed before running
  end

  after do
    # executed when the task successed
  end

  around do |body|
    body.call # `run` method is called
  ensure
    ...       # executed even if the task failed
  end
end
```

### Extending plays

You can extend plays in object-oriented style.
All parameters, settings and methods are inherited.

```ruby
play :abstract_count do
  def run
    `hive -f #{file_path}`
  end
end

play :count, extends: :abstract_count do
  set :file_path, 'sql/count.sql'
end

---

$ abid count #=> hive -f sql/count.sql
```

Common base play can be defined by `play_base` keyword:

```
play_base do
  param :date, type: :date
end
```

All plays inherit the `play_base` definition.

### Plays internal

The play implementation can be illustrated as below:

```ruby
play :sample do
  param :date, type: :date
  set(:file_path, 'sql/count.sql')
  set(:query) { File.read(file_path) }
  def run
    ...
  end
end

# <=>

class Sample < Abid::Play
  attr_reader :date
  def initialize(date)
    @date = Date.parse(date)
  end

  def file_path
    'sql/count.sql'
  end
  def query
    @query ||= File.read(file_path)
  end

  def run
    ...
  end
end

task :sample do
  Sample.new(ENV['date']).run
end
```

When play is defined, new subclass of Avid::Play is created and play body is evaluated in that new class context. So, any class goodies can be put in play's body, i.e. including modules, `attr_reader` / `attr_writer`, method definitions, etc..

## Built-in tasks

### `state:list`

```
$ abid state:list started_after="2000-01-01 00:00:00" started_before="2000=01-02 00:00:00"
```

Display plays current states.

### `state:revoke`

```
$ abid state:revoke[id]
```

Remove the play recored from DB.

### `state:assume`

```
$ abid state:assume[task_name] date=2000-01-01
```

Insert a record that the play successed into DB.

### `db:migrate`

```
$ abid db:migrate
```

Initialize or update DB.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ojima-h/abid. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
