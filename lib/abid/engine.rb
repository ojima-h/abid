module Abid
  # Engine module operates task execution.
  module Engine
    def self.invoke(job)
      Scheduler.detect_circular_dependency(job)
      Scheduler.new(job).invoke
      job.process.wait
    end
  end
end
