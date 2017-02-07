module Abid
  class Engine
    # @!visibility private

    # Executor operates each job execution.
    class Executor
      def initialize(process, args)
        @process = process
        @job = process.job
        @args = args

        @state = @process.state_service.find
        @prerequisites = process.prerequisites
        @worker = @process.engine.worker_manager[@job.worker]
      end

      # Check if the job should be executed.
      #
      # @return [Boolean] false if the job should not be executed.
      def prepare
        return unless @process.prepare
        return false if precheck_to_cancel
        return false if precheck_to_skip
        true
      end

      # Start processing the job.
      #
      # The job is executed asynchronously.
      #
      # @return [Boolean] false if the job is not executed
      def start
        return false unless @prerequisites.all?(&:complete?)

        return false if check_to_cancel
        return false if check_to_skip

        return false unless @process.start
        execute_or_wait
        true
      end

      private

      # Cancel the job if it should be.
      # @return [Boolean] true if cancelled
      def precheck_to_cancel
        return false if @job.repair?
        return false unless @state.failed?
        return false if @process.root?
        @process.cancel(Error.new('task has been failed'))
      end

      # Skip the job if it should be.
      # @return [Boolean] true if skipped
      def precheck_to_skip
        return false if @job.options.force
        return @process.skip unless @job.concerned?

        return false if @job.repair? && !@prerequisites.empty?
        return false unless @state.successed?
        @process.skip
      end

      # Cancel the job if it should be.
      # @return [Boolean] true if cancelled
      def check_to_cancel
        return false if @prerequisites.empty?
        return false if @prerequisites.all? { |p| !p.failed? && !p.cancelled? }
        @process.cancel
      end

      # Skip the job if it should be.
      # @return [Boolean] true if skipped
      def check_to_skip
        return @process.skip unless @job.needed?

        return false if @prerequisites.empty?
        return false unless @job.repair?
        return false if @prerequisites.any?(&:successed?)
        @process.skip
      end

      # Post the job if no external process executing the same job, wait the
      # job finished otherwise.
      def execute_or_wait
        if @process.state_service.try_start
          @worker.post { @process.capture_exception { execute } }
        else
          Waiter.new(@process).wait
        end
      end

      def execute
        _, error = safe_execute

        @process.state_service.finish(error)
        @process.finish(error)
      end

      def safe_execute
        @job.execute(@args)
        true
      rescue => error
        [false, error]
      end
    end
  end
end
