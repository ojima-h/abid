require 'sequel/plugins/serialization'
require 'abid/state_manager/state'
require 'abid/state_manager/state_proxy'

module Abid
  module StateManager
    class Database
      Sequel.extension :migration

      MIGRATIONS_PATH = File.expand_path('../../../../migrations', __FILE__)

      # Creates a new database object and checks schema version.
      #
      # @return [Sequel::Database] database object
      # @see Sequel.connect
      def self.connect(*args)
        db = Sequel.connect(*args)
        Sequel::Migrator.check_current(db, MIGRATIONS_PATH)
        db
      rescue Sequel::Migrator::NotCurrentError
        raise Error, 'current schema is out of date'
      end

      def initialize(env)
        @env = env
        @mon = Monitor.new
      end

      def connection
        @connection ||= self.class.connect(@env.config.database)
      end

      def states
        @mon.synchronize do
          @states ||= Class.new(State.Model(connection[:states]))
        end
      end
    end
  end
end
