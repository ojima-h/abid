require 'sequel/plugins/serialization'
require 'abid/state_manager/state'
require 'abid/state_manager/state_service'

module Abid
  class StateManager
    Sequel.extension :migration

    MIGRATIONS_PATH = File.expand_path('../../../migrations', __FILE__)

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
      @db = self.class.connect(@env.config.database)
      @states = State.connect(@db)
    end
    attr_reader :db, :states

    # Returns StateService object from name and params.
    # @param name [String] task name
    # @param params [Hash]
    # @return [StateManager::StateService]
    def state(name, params, dryrun: false, volatile: false)
      return VolatileStateService.new(@states, name, params) if volatile
      return NullStateService.new(@states, name, params) if dryrun
      StateService.new(@states, name, params)
    end
  end
end
