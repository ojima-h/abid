module Abid
  class Engine
    class JobManager
      def initialize(engine)
        @engine = engine
        @jobs = {}.compare_by_identity
        @actives = {}.compare_by_identity
        @summary = Hash.new { |h, k| h[k] = 0 }
        @mon = Monitor.new
      end
      attr_reader :summary

      def [](task)
        return @jobs[task] if @jobs.include?(task)

        @mon.synchronize do
          @jobs[task] ||= Job.new(@engine, task)
        end
      end

      # Update active jobs list
      def update(job)
        update_actives(job)
        update_summary(job)
        log(job)
      end

      # Kill all active jobs
      # @param error [Exception] error reason
      def kill(error)
        actives.each { |j| j.process.quit(error) }
      end

      def actives
        @actives.values
      end

      def active?(job)
        @actives.include?(job)
      end

      def pretty_summary
        return if summary.empty?

        keys = [:successed, :failed, :skipped, :cancelled]
        width = keys.map(&:length).max
        keys.each_with_object('') do |key, ret|
          ret << format("% #{width}s: %d\n", key, @summary[key])
        end
      end

      private

      def update_actives(job)
        case job.process.status
        when :pending, :running
          @actives[job] = job
        when :complete
          @actives.delete(job)
        end
      end

      def update_summary(job)
        return unless job.process.status == :complete
        @mon.synchronize { @summary[job.process.result] += 1 }
      end

      def log(job)
        case job.process.status
        when :running
          log_start(job)
        when :complete
          log_finish(job)
          log_error(job.process.error)
        end
      end

      def log_start(job)
        task = job.task
        sig = ParamsFormat.format_with_name(task.name, task.params)
        @engine.logger.info("#{sig} start.")
      end

      def log_finish(job)
        task = job.task
        sig = ParamsFormat.format_with_name(task.name, task.params)

        if job.process.failed?
          @engine.logger.error("#{sig} failed.")
        else
          @engine.logger.info("#{sig} #{job.process.result}.")
        end
      end

      def log_error(error)
        return if error.nil?
        @engine.logger.error(format_error_backtrace(error))
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
