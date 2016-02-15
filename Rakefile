require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

task :default => :test

namespace :db do
  desc 'Run migrations'
  task :migrate, [:version] do |_t, args|
    require 'sqlite3'
    require 'sequel'

    database_url = 'sqlite://' + File.expand_path('../tmp/abid.db', __FILE__)
    migrations_path = File.expand_path('../migrations', __FILE__)

    require 'sequel'
    Sequel.extension :migration
    db = Sequel.connect(database_url)
    if args[:version]
      puts "Migrating to version #{args[:version]}"
      Sequel::Migrator.run(db, migrations_path, target: args[:version].to_i)
    else
      puts 'Migrating to latest'
      Sequel::Migrator.run(db, migrations_path)
    end
  end
end
