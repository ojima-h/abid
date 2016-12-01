module Abid
  module StateManager
    # O/R Mapper for `states` table.
    class State < Sequel::Model(StateManager.database)
      RUNNING = 1
      SUCCESSED = 2
      FAILED = 3

      plugin :serialization
      serialize_attributes(
        [
          ->(params) { ParamsFormat.dump(params) },
          ->(params) { ParamsFormat.load(params) }
        ],
        :params
      )

      def before_create
        self.digest = ParamsFormat.digest(name, params)
        super
      end

      # check if the state is running
      def check_running!
        raise AlreadyRunningError, 'job already running' if running?
      end

      def running?
        state == RUNNING
      end

      def successed?
        state == SUCCESSED
      end

      def failed?
        state == FAILED
      end
    end
  end
end
