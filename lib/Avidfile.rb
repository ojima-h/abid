desc 'Run migrations'
task :migrate, [:version] do |_t, args|
  database_url = Rake.application.config['avid']['database_url']
  migrations_path = File.expand_path('../../migrations', __FILE__)

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
