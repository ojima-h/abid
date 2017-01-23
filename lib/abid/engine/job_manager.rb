require 'monitor'

module Abid
  class Engine
    class JobManager
      def initialize(engine)
        @engine = engine
        @jobs = {}.compare_by_identity
        @mon = Monitor.new
      end

      def [](task)
        return @jobs[task] if @jobs.include?(task)

        @mon.synchronize do
          @jobs[task] ||= Job.new(@engine, task)
        end
      end
    end
  end
end
