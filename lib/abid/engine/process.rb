require 'concurrent/ivar'
require 'forwardable'
require 'monitor'

module Abid
  class Engine
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

      def_delegators :@result_ivar, :add_observer, :wait, :complete?

      def initialize(job)
        @job = job
        @result_ivar = Concurrent::IVar.new
        @status = :unscheduled
        @error = nil
        @mon = Monitor.new

        @result_ivar.add_observer { notify_job }
      end
      attr_reader :status, :error

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

      def prepare
        compare_and_set_status(:pending, :unscheduled)
      end

      def start
        compare_and_set_status(:running, :pending)
      end

      def finish(error = nil)
        return unless compare_and_set_status(:complete, :running)
        @error = error if error
        @result_ivar.set(error.nil? ? :successed : :failed)
        true
      end

      def cancel(error = nil)
        return false unless compare_and_set_status(:complete, :pending)
        @error = error if error
        @result_ivar.set :cancelled
        true
      end

      def skip
        return false unless compare_and_set_status(:complete, :pending)
        @result_ivar.set :skipped
        true
      end

      # Force fail the task.
      # @return [void]
      def quit(error)
        @status = :complete
        @error = error
        @result_ivar.try_set(:failed).tap do |changed|
          notify_job unless changed
        end
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
        @mon.synchronize do
          return unless expected_current.include? @status
          @status = next_state
          notify_job unless @status == :complete
          true
        end
      end

      def notify_job
        @job.update_status
      end
    end
  end
end
