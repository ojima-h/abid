require 'abid/state_manager/database'

module Abid
  # StateManager manages jobs execution status and history.
  #
  # It ensures that same task is not executed simultaneously.
  # Further more, it remembers all jobs history and prevents successed jobs to
  # be executed again.
  module StateManager
    # @return [Sequel::Database] database object
    def self.database
      @database ||= Database.connect
    end

    autoload :State, 'abid/state_manager/state'
  end
end
