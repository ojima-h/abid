module Abid
  module StateManager
    # O/R Mapper for `states` table.
    class State < Sequel::Model(StateManager.database)
      RUNNING = 1
      SUCCESSED = 2
      FAILED = 3

      # @!method self.filter_by_start_time(after: nil, before: nil)
      #   @param after [Time] lower bound of start_time
      #   @param before [Time] upper bound of start_time
      #   @return [Sequel::Dataset<State>] a set of states started between
      #     the given range.
      #
      # @!method self.filter_by_prefix(prefix)
      #   @param prefix [String] the prefix of task names
      #   @return [Sequel::Dataset<State>] a set of states which name starts
      #     with the given prefix.
      dataset_module do
        def filter_by_start_time(after: nil, before: nil)
          dataset = self
          dataset = dataset.where { start_time >= after } if after
          dataset = dataset.where { start_time <= before } if before
          dataset
        end

        def filter_by_prefix(prefix)
          return self if prefix.nil?
          where { Sequel.like(:name, prefix + '%') }
        end
      end

      # Find a state by the job.
      #
      # @param job [Job] job
      # @return [State] state object
      def self.find_by_job(job)
        where(
          name: job.name,
          params: job.params_str,
          digest: job.digest
        ).first
      end

      # Initialize a state by a job.
      #
      # @param job [Job] job
      # @return [State] state object
      def self.init_by_job(job)
        new(
          name: job.name,
          params: job.params_str,
          digest: job.digest
        )
      end

      # Assume the job to be successed
      #
      # If the force option is true, update the state to SUCCESSED even if the
      # task is running.
      #
      # @param force [Boolean] force update the state
      # @return [void]
      def assume(force: false)
        StateManager.database.transaction do
          return if successed?
          check_running! unless force

          self.state = SUCCESSED
          self.start_time = Time.now
          self.end_time = Time.now
          save
        end
      end

      # Delete the state.
      #
      # @param force [Boolean] If true, delete the state even if running
      # @return [void]
      def revoke(force: false)
        StateManager.database.transaction do
          unless force
            refresh
            check_running!
          end
          delete
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
    end
  end
end
