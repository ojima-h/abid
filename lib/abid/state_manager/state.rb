module Abid
  module StateManager
    # O/R Mapper for `states` table.
    class State < Sequel::Model(StateManager.database)
      RUNNING = 1
      SUCCESSED = 2
      FAILED = 3

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

      def self.find_or_initialize_by_job(job)
        find_by_job(job) || \
          new(name: job.name, params: job.params_str, digest: job.digest)
      end

      # Assume the job to be successed
      #
      # If the force option is true, update the state to SUCCESSED even if the
      # task is running.
      #
      # @param job [Job] job
      # @param force [Boolean] force update the state
      # @return [State] state object
      def self.assume(job, force: false)
        StateManager.database.transaction do
          state = find_or_initialize_by_job(job)

          return state if state.successed?
          state.check_running! unless force

          state.state = SUCCESSED
          state.start_time = Time.now
          state.end_time = Time.now
          state.save
          state
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
    end
  end
end
