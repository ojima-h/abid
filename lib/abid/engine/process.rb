require 'forwardable'

module Abid
  class Engine
    # @!visibility private

    # Process object manages the job execution status.
    #
    # You should retrive a process object via Job#process.
    # Do not create a process object by Process.new constructor.
    #
    # A process object has an internal status of the job execution.
    #
    # An initial status is :unscheduled.
    # When Process#prepare is called, the status gets :pending.
    # When Process#execute is called and the job is posted to a thread pool,
    # the status gets :running. When the job is finished, the status gets
    # :successed or :failed.
    #
    #     process = Job['job_name'].process
    #     process.prepare
    #     process.start
    #     process.wait
    #     process.status #=> :successed or :failed
    #
    # Possible status are:
    #
    # <dl>
    #   <dt>:unscheduled</dt>
    #   <dd>The job is not invoked yet.</dd>
    #   <dt>:pending</dt>
    #   <dd>The job is waiting for prerequisites complete.</dd>
    #   <dt>:running</dt>
    #   <dd>The job is running.</dd>
    #   <dt>:successed</dt>
    #   <dd>The job is successed.</dd>
    #   <dt>:failed</dt>
    #   <dd>The job is failed.</dd>
    #   <dt>:cancelled</dt>
    #   <dd>The job is not executed because of some problems.</dd>
    #   <dt>:skipped</dt>
    #   <dd>The job is not executed because already successed.</dd>
    # </dl>
    class Process
      extend Forwardable

      def initialize(engine, job)
        @engine = engine
        @job = job
        @status = Status.new(:unscheduled)
        @error = nil
        initialize_logger(job)
        initialize_state_service(job)
      end
      attr_reader :error, :engine, :job
      def_delegators :@status, :on_update, :on_complete, :wait, :complete?

      def initialize_logger(job)
        @logger = @engine.logger.clone
        pn = @logger.progname
        @logger.progname = pn ? "#{pn}: #{job}" : job.to_s
      end
      private :initialize_logger
      attr_reader :logger

      def initialize_state_service(job)
        @state_service = @engine.state_manager.state(
          job.name, job.params,
          dryrun: job.dryrun? || job.preview?,
          volatile: job.volatile?
        )
      end
      private :initialize_state_service
      attr_reader :state_service

      def prerequisites
        @job.prerequisites.map { |preq| @engine.process_manager[preq] }
      end

      #
      # State predicates
      #
      %w(unscheduled pending running
         successed failed cancelled skipped).each do |meth|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{meth}?
          @status.get == :#{meth}
        end
        RUBY
      end

      def root?
        @engine.process_manager.root?(self)
      end

      def status
        @status.get
      end

      def prepare
        @status.compare_and_set(:unscheduled, :pending)
      end

      def start
        return unless @status.compare_and_set(:pending, :running)
        @logger.info('start.')
      end

      def finish(error = nil)
        error.nil? ? successed : failed(error)
      end

      def successed
        return unless @status.compare_and_set(:running, :successed, true)
        @logger.info('successed.')
      end

      def failed(error)
        log_error(error)
        return unless @status.compare_and_set(:running, :failed, true)
        @logger.error('failed.')
      end

      def cancel(error = nil)
        log_error(error) if error
        return unless @status.compare_and_set(:pending, :cancelled, true)
        @logger.info('cancelled.')
      end

      def skip
        return unless @status.compare_and_set(:pending, :skipped, true)
        @logger.info('skipped')
      end

      # Force fail the job.
      # @return [void]
      def quit(error)
        log_error(error)
        @status.try_set(:failed, true)
      end

      def capture_exception
        yield
      rescue StandardError, ScriptError => error
        quit(error)
      rescue Exception => exception
        # kill from independent thread
        Thread.start { @engine.kill(exception) }
      end

      private

      def log_error(error)
        @error = error
        @logger.error(format_error_backtrace(error))
      end

      def format_error_backtrace(error)
        if error.backtrace.nil? || error.backtrace.empty?
          return "#{error.message} (#{error.class})"
        end

        bt = error.backtrace
        ret = ''
        ret << "#{bt.first}: #{error.message} (#{error.class})\n"
        bt.each { |b| ret << "    from #{b}\n" }
        ret
      end
    end
  end
end
