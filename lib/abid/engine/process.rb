require 'concurrent/ivar'
require 'forwardable'

module Abid
  module Engine
    # @!visibility private

    # Process object manages the task execution status.
    #
    # You should retrive a process object via Job#process.
    # Do not create a process object by Process.new constructor.
    #
    # A process object has a state of the task execution (Process#state) and
    # the task result (Process#result).
    #
    # An initial state is :unscheduled.
    # When Process#execute is called and the task is posted to a thread pool,
    # the state gets :processing. When the task is finished, the state gets
    # :complete and the result is assigned to :successed or :failed.
    #
    #     process = Job['task_name'].process
    #     process.execute
    #     process.result.value #=> :successed or :failed
    #     process.state #=> :complete
    #
    # Possible results are:
    #
    # <dl>
    #   <dt>:successed</dt>
    #   <dd>The task is successed.</dd>
    #   <dt>:failed</dt>
    #   <dd>The task is failed.</dd>
    #   <dt>:cancelled</dt>
    #   <dd>The task is not executed because some prerequisite task is failed.
    #   </dd>
    #   <dt>:skipped</dt>
    #   <dd>The task is not executed because already successed.</dd>
    # </dl>
    class Process
      extend Forwardable

      attr_reader :state, :error

      def_delegators :@result_ivar, :add_observer, :wait, :complete?

      def initialize(job)
        @job = job
        @result_ivar = Concurrent::IVar.new
        @state = :unscheduled
      end

      def result
        @result_ivar.value!
      end

      # Execute the task in the task's worker thread.
      #
      # @return [Boolean] false if the state is processing or complete.
      def execute
        return false unless compare_and_set_state(:processing, :unscheduled)
        run
        true
      end

      # Set the state to :complete and the result to :failed
      #
      # @return [Boolean] false if the state is processing or complete.
      def fail(error)
        return false unless compare_and_set_state(:complete, :unscheduled)
        @result_ivar.set :failed
        @error = error
        true
      end

      # Set the state to :complete and the result to :canceled
      #
      # @return [Boolean] false if the state is processing or complete.
      def cancel
        return false unless compare_and_set_state(:complete, :unscheduled)
        @result_ivar.set :cancelled
        true
      end

      # Set the state to :complete and the result to :skipped
      #
      # @return [Boolean] false if the state is processing or complete.
      def skip
        return false unless compare_and_set_state(:complete, :unscheduled)
        @result_ivar.set :skipped
        true
      end

      private

      # Atomic compare and set operation
      # State is set to `next_state` only if
      # `current state == expected_current`.
      #
      # @param [Symbol] next_state
      # @param [Symbol] expected_current
      #
      # @return [Boolean] true if state is changed, false otherwise
      def compare_and_set_state(next_state, *expected_current)
        Job.synchronize do
          return unless expected_current.include? @state
          @state = next_state
          true
        end
      end

      # Post the task if no external process executing the same task, wait the
      # task finished otherwise.
      def run
        if @job.try_start
          post_task
        else
          wait_task
        end
      end

      def worker
        Abid.application.worker[@job.task.worker]
      end

      def post_task
        worker.post do
          _, error = safe_execute
          @job.finish(error)
          complete(error)
        end
      end

      # Execute the task immediately.
      #
      # @return [Boolean, Exception] false if an error is raised, otherwise true
      def safe_execute
        @job.task.execute
        true
      rescue Exception => error
        # TODO: exit immediately when fatal error occurs.
        # rescue StandardError, ScriptError => error
        [false, error]
      end

      def wait_task
        return complete AlreadyRunningError.new('job already running')

        # TODO: implement external task waiting
        Engine.wait(@job) do |result|
          if result
            complete
          else
            complete ExternalFailure.new(@job.task.to_s)
          end
        end
      end

      # Set the state to :complete and the result to :successed or :failed
      # according to the `error`.
      def complete(error = nil)
        Job.synchronize do
          @state = :complete
          @error = error
        end
        @result_ivar.set(error.nil? ? :successed : :failed)
      end
    end
  end
end
