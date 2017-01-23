module Abid
  class CLI
    class Migrate
      def initialize(env, options)
        @env = env
        @options = options
      end

      def run
        db = Sequel.connect(@env.config.database)
        dir = StateManager::MIGRATIONS_PATH

        if Sequel::Migrator.is_current?(db, dir)
          puts 'Schema is latest.'
          return
        end

        puts 'Start migration...'
        Sequel::Migrator.run(db, dir)
        puts 'Done'
      end
    end
  end
end
