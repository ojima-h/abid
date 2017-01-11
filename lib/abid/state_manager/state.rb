module Abid
  module StateManager
    State = Class.new(Sequel::Model)

    # O/R Mapper for `states` table.
    #
    # Use #init_by_job to initialize a state object.
    class State
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

      # Find or initialize a state by a job.
      #
      # @param job [Job] job
      # @return [State] state object
      def self.find_or_init_by_job(job)
        find_by_job(job) || init_by_job(job)
      end

      # Update the state to RUNNING.
      #
      # @param job [Job] job
      def self.start(job)
        db.transaction do
          state = find_or_init_by_job(job)
          state.check_running!
          state.state = RUNNING
          state.start_time = Time.now
          state.end_time = nil
          state.save
        end
      end

      # Update the state to SUCCESSED or FAILED.
      #
      # If error is given, the state will be FAILED.
      #
      # @param job [Job] job
      # @param error [Error] error object
      def self.finish(job, error = nil)
        db.transaction do
          state = find_or_init_by_job(job)
          return unless state.running?

          state.state = error ? FAILED : SUCCESSED
          state.end_time = Time.now
          state.save
        end
      end

      # Assume the job to be successed
      #
      # If the force option is true, update the state to SUCCESSED even if the
      # task is running.
      #
      # @param job [Job] job
      # @param force [Boolean] force update the state
      # @return [void]
      def self.assume(job, force: false)
        db.transaction do
          state = find_or_init_by_job(job)
          return state if state.successed?
          state.check_running! unless force

          state.state = SUCCESSED
          state.start_time = Time.now
          state.end_time = Time.now
          state.save
          state
        end
      end

      # Delete the state.
      #
      # @param state_id [Integer] State ID
      # @param force [Boolean] If true, delete the state even if running
      # @return [void]
      def self.revoke(state_id, force: false)
        db.transaction do
          state = self[state_id]
          return false if state.nil?
          state.check_running! unless force
          state.delete
          true
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
