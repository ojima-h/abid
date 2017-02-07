require 'concurrent/atomic/atomic_reference'

module Abid
  class Engine
    # JobManager is a jobs repositry and tracks each job progress.
    class JobManager
      def initialize(engine)
        @engine = engine
        @jobs = {}.compare_by_identity
        @actives = {}.compare_by_identity
        @top_levels = {}.compare_by_identity
        @summary = Hash.new { |h, k| h[k] = 0 }
        @errors = []
        @mon = Monitor.new
        @status = Concurrent::AtomicReference.new(:running)
      end
      attr_reader :summary, :errors

      def [](task)
        return @jobs[task] if @jobs.include?(task)

        @mon.synchronize do
          @jobs[task] ||= Job.new(@engine, task)
        end
      end

      # @param task [DSL::TaskInstance]
      # @param args [Array<Object>]
      # @return [Job]
      def invoke(task, args)
        raise Error, 'JobManager is not running now' unless running?

        job = self[task]
        @top_levels[job] = job
        Scheduler.invoke(job, *args)
        job.process.wait
        job
      end

      # Update active jobs list
      def update(job)
        update_actives(job)
        update_summary(job)
      end

      def shutdown
        return unless @status.compare_and_set(:running, :shuttingdown)
        actives.each { |job| job.process.wait }
        @status.set(:shutdown)
      end

      # Kill all active jobs
      # @param error [Exception] error reason
      def kill(error)
        return if shutdown?
        @status.set(:shutdown)
        actives.each { |j| j.process.quit(error) }
      end

      def actives
        @actives.values
      end

      def active?(job)
        @actives.include?(job)
      end

      def root?(job)
        @top_levels.include?(job)
      end

      %w(running shuttingdown shutdown).each do |meth|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{meth}?
          @status.get == :#{meth}
        end
        RUBY
      end

      private

      def update_actives(job)
        if job.process.complete?
          @actives.delete(job)
        else
          @actives[job] = job
        end
      end

      def update_summary(job)
        return unless job.process.complete?
        return if job.dryrun?
        @mon.synchronize { @summary[job.process.status] += 1 }
        @errors << job.process.error if job.process.error
      end
    end
  end
end
