require 'forwardable'

module Abid
  module StateManager
    # StateProxy provides accessor methods to State for Job#state.
    #
    # StateProxy holds a reference to the job, and find corresponding state
    # every time when needed.
    #
    # Use StateProxy#find if you have to access the undergrounding State object
    # many times.
    class StateProxy
      def initialize(job)
        @job = job
        @states = job.env.db.states
      end

      # Find underlying State object
      #
      # @return [State] state corresponding the job.
      def find
        if @job.volatile?
          @states.init_by_job(@job).tap(&:freeze)
        else
          @states.find_or_init_by_job(@job).tap(&:freeze)
        end
      end
      alias instance find

      # Update the state to started unless volatile.
      # @see State.start
      def start
        return if @job.dryrun? || @job.volatile?
        @states.start(@job)
      end

      # Try to update the state to started unless volatile.
      # @see State.start
      # @return [Boolean] false if already running
      def try_start
        start
        true
      rescue AlreadyRunningError
        false
      end

      # Update the state to SUCCESSED / FAILED unless volatile.
      # @see State.finish
      def finish(error = nil)
        return if @job.dryrun? || @job.volatile?
        @states.finish(@job, error)
      end

      def assume(force: false)
        @states.assume(@job, force: force)
      end

      # for testing
      def mock_fail(error)
        start
        finish(error)
      end
    end
  end
end
