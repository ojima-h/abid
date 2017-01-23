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

    # Returns StateService object from signature.
    # @param signature [Signature]
    # @return [StateManager::StateService]
    def state(signature, dryrun: false, volatile: false)
      return VolatileStateService.new(@states, signature) if volatile
      return NullStateService.new(@states, signature) if dryrun
      StateService.new(@states, signature)
    end
  end
end
