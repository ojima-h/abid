require 'concurrent/utility/monotonic_time'

module Abid
  class Engine
    # Waits for a process to be finished which is running in external
    # application, and completes the process in its own application.
    #
    #     Waiter.new(process).wait
    #
    # The `process` result gets :successed or :failed when external application
    # finished the process execution.
    class Waiter
      DEFAULT_WAIT_INTERVAL = 10
      DEFAULT_WAIT_TIMEOUT = 3600

      def initialize(process)
        @process = process
        @job = process.job
        @wait_limit = Concurrent.monotonic_time + wait_timeout
      end

      def wait
        unless @job.options.wait_external_task
          @process.finish(AlreadyRunningError.new('process already running'))
          return
        end

        @process.logger.info('waiting')
        wait_iter
      end

      private

      def wait_interval
        @job.options.wait_external_task_interval || DEFAULT_WAIT_INTERVAL
      end

      def wait_timeout
        @job.options.wait_external_task_timeout || DEFAULT_WAIT_TIMEOUT
      end

      def wait_iter
        @process.engine.worker_manager[:timer_set].post(wait_interval) do
          @process.capture_exception do
            state = @process.state_service.find

            check_finished(state) || check_timeout || wait_iter
          end
        end
      end

      def check_finished(state)
        return false if state.running?

        if state.successed?
          @process.finish
        elsif state.failed?
          @process.finish RuntimeError.new('task failed while waiting')
        else
          @process.finish RuntimeError.new('unexpected task state')
        end
        true
      end

      def check_timeout
        return false if Concurrent.monotonic_time < @wait_limit

        @process.finish RuntimeError.new('timeout')
        true
      end
    end
  end
end
