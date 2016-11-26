require 'abid/state_manager'

module Abid
  class CLI
    class Migrate
      def initialize(options)
        @options = options
      end

      def run
        db = StateManager::Database.connect!
        dir = StateManager::Database.migrations_path

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
