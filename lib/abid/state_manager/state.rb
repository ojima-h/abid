require 'yaml'

module Abid
  class StateManager
    # O/R Mapper for `states` table.
    module State
      def self.connect(database)
        mod = self
        Class.new(Sequel::Model(database[:states])) do
          include mod
          dataset_module mod.const_get(:DatasetMethods)
        end
      end

      RUNNING = 1
      SUCCESSED = 2
      FAILED = 3

      module DatasetMethods
        #   @param after [Time] lower bound of start_time
        #   @param before [Time] upper bound of start_time
        #   @return [Sequel::Dataset<State>] a set of states started between
        #     the given range.
        def filter_by_start_time(after: nil, before: nil)
          dataset = self
          dataset = dataset.where { start_time >= after } if after
          dataset = dataset.where { start_time <= before } if before
          dataset
        end

        #   @param prefix [String] the prefix of task names
        #   @return [Sequel::Dataset<State>] a set of states which name starts
        #     with the given prefix.
        def filter_by_prefix(prefix)
          return self if prefix.nil?
          where { Sequel.like(:name, prefix + '%') }
        end
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

      def state_label
        case state
        when 1 then 'RUNNING'
        when 2 then 'SUCCESSED'
        when 3 then 'FAILED'
        else 'UNKNOWN'
        end
      end

      def exec_time
        return unless start_time && end_time
        end_time - start_time
      end

      # Update the state to RUNNING.
      def start
        check_running!
        update(state: RUNNING, start_time: Time.now, end_time: nil)
      end

      # Update the state to SUCCESSED or FAILED.
      # If error is given, the state will be FAILED.
      def finish(error = nil)
        return unless running?
        update(state: error ? FAILED : SUCCESSED, end_time: Time.now)
      end

      # Assume the job to be successed
      #
      # If the `force` option is true, update the state to SUCCESSED even if the
      # task is running.
      def assume(force: false)
        return if successed?
        check_running! unless force
        time = Time.now
        update(state: SUCCESSED, start_time: time, end_time: time)
      end

      # Delete the state.
      # @param force [Boolean] If true, delete the state even if running
      def revoke(force: false)
        check_running! unless force
        delete
      end

      def params_hash
        YAML.load(params)
      end
    end
  end
end
