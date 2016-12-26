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
    # A process object has an internal status of the task execution and
    # the task result (Process#result).
    #
    # An initial status is :unscheduled.
    # When Process#prepare is called, the status gets :pending.
    # When Process#execute is called and the task is posted to a thread pool,
    # the status gets :running. When the task is finished, the status gets
    # :complete and the result is assigned to :successed or :failed.
    #
    #     process = Job['task_name'].process
    #     process.prepare
    #     process.start
    #     process.wait
    #     process.result #=> :successed or :failed
    #
    # Possible status are:
    #
    # <dl>
    #   <dt>:unscheduled</dt>
    #   <dd>The task is not invoked yet.</dd>
    #   <dt>:pending</dt>
    #   <dd>The task is waiting for prerequisites complete.</dd>
    #   <dt>:running</dt>
    #   <dd>The task is running.</dd>
    #   <dt>:complete</dt>
    #   <dd>The task is finished.</dd>
    # </dl>
    #
    # Possible results are:
    #
    # <dl>
    #   <dt>:successed</dt>
    #   <dd>The task is successed.</dd>
    #   <dt>:failed</dt>
    #   <dd>The task is failed.</dd>
    #   <dt>:cancelled</dt>
    #   <dd>The task is not executed because of some problems.</dd>
    #   <dt>:skipped</dt>
    #   <dd>The task is not executed because already successed.</dd>
    # </dl>
    class Process
      extend Forwardable

      attr_reader :status, :error

      def_delegators :@result_ivar, :add_observer, :wait, :complete?

      def initialize(job)
        @job = job
        @prerequisites = @job.prerequisites.map(&:process)
        @result_ivar = Concurrent::IVar.new
        @status = :unscheduled
      end

      %w(successed failed cancelled skipped).each do |meth|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{meth}?
          result == :#{meth}
        end
        RUBY
      end

      def result
        @result_ivar.value if @result_ivar.complete?
      end

      # Check if the task should be executed.
      #
      # If not, the status will be :complete and the result will be :skipped or
      # :cancelled, otherwise the status will be :pending.
      #
      # @return [Boolean] false if the task should not be executed.
      def prepare
        return false unless compare_and_set_status(:pending, :unscheduled)

        state = @job.state.find
        return false if precheck_to_cancel(state)
        return false if precheck_to_skip(state)
        true
      end

      # Start processing the task.
      #
      # The task is executed asynchronously.
      #
      # @return [Boolean] false if the task is not executed
      def start
        return false unless @prerequisites.all?(&:complete?)
        return false unless compare_and_set_status(:starting, :pending)

        return false if check_to_cancel
        return false if check_to_skip
        execute_or_wait
        true
      end

      # Force fail the task.
      # @return [void]
      def quit(error)
        @status = :complete
        @error = error
        @result_ivar.try_set(:failed)
      end

      def capture_exception
        yield
      rescue StandardError, ScriptError => error
        quit(error)
      rescue Exception => exception
        # TODO: exit immediately when fatal error occurs.
        quit(exception)
      end

      private

      # Atomic compare and set operation.
      # State is set to `next_state` only if
      # `current state == expected_current`.
      #
      # @param [Symbol] next_state
      # @param [Symbol] expected_current
      #
      # @return [Boolean] true if state is changed, false otherwise
      def compare_and_set_status(next_state, *expected_current)
        Job.synchronize do
          return unless expected_current.include? @status
          @status = next_state
          true
        end
      end

      # Cancel the task if it should be.
      # @return [Boolean] true if cancelled
      def precheck_to_cancel(state)
        return if Abid.application.options.repair
        return unless state.failed?
        return if @job.task.top_level?
        return unless compare_and_set_status(:complete, :pending)
        @error = Error.new('task has been failed')
        @result_ivar.set :cancelled
        true
      end

      # Skip the task if it should be.
      # @return [Boolean] true if skipped
      def precheck_to_skip(state)
        return if Abid.application.options.repair && !@prerequisites.empty?
        return unless state.successed?
        return unless compare_and_set_status(:complete, :pending)
        @result_ivar.set :skipped
        true
      end

      # Cancel the task if it should be.
      # @return [Boolean] true if cancelled
      def check_to_cancel
        return if @prerequisites.empty?
        return if @prerequisites.all? { |p| !p.failed? && !p.cancelled? }
        return unless compare_and_set_status(:complete, :starting)
        @result_ivar.set :cancelled
        true
      end

      # Skip the task if it should be.
      # @return [Boolean] true if skipped
      def check_to_skip
        return if @prerequisites.empty?
        return unless Abid.application.options.repair
        return if @prerequisites.any?(&:successed?)
        return unless compare_and_set_status(:complete, :starting)
        @result_ivar.set :skipped
        true
      end

      # Post the task if no external process executing the same task, wait the
      # task finished otherwise.
      def execute_or_wait
        return unless compare_and_set_status(:running, :starting)
        if @job.state.try_start
          worker.post { capture_exception { execute } }
        else
          wait_task
        end
      end

      def worker
        Abid.application.worker[@job.task.worker]
      end

      def execute
        _, error = safe_execute

        return unless compare_and_set_status(:complete, :running)
        @job.state.finish(error)
        @error = error
        @result_ivar.set(error.nil? ? :successed : :failed)
      end

      def safe_execute
        @job.task.execute
        true
      rescue => error
        [false, error]
      end

      def wait_task
        return unless compare_and_set_status(:complete, :running)
        @error = AlreadyRunningError.new('job already running')
        @result_ivar.set(:failed)

        # TODO: implement external task waiting
      end
    end
  end
end
