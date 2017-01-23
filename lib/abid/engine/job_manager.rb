require 'monitor'

module Abid
  class Engine
    class JobManager
      def initialize(engine)
        @engine = engine
        @jobs = {}.compare_by_identity
        @actives = {}.compare_by_identity
        @mon = Monitor.new
      end

      def [](task)
        return @jobs[task] if @jobs.include?(task)

        @mon.synchronize do
          @jobs[task] ||= Job.new(@engine, task)
        end
      end

      # Update active jobs list
      def update(job)
        case job.process.status
        when :pending, :running
          @actives[job] = job
        when :complete
          @actives.delete(job)
        end
      end

      # Kill all active jobs
      # @param error [Exception] error reason
      def kill(error)
        actives.each { |j| j.process.quit(error) }
      end

      def actives
        @actives.value
      end

      def active?(job)
        @actives.include?(job)
      end
    end
  end
end
