module Abid
  class CLI
    class Migrate
      def initialize(options)
        @options = options
      end

      def run
        migrations_path = File.expand_path('../../../../migrations', __FILE__)

        Sequel.extension :migration
        db = Abid.application.database

        if Sequel::Migrator.is_current?(db, migrations_path)
          puts 'Schema is latest.'
          return
        end

        puts 'Start migration...'
        Sequel::Migrator.run(db, migrations_path)
        puts 'Done'
      end
    end
  end
end
