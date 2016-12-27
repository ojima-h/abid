module Abid
  # Engine module operates task execution.
  module Engine
    def self.invoke(*args)
      Scheduler.invoke(*args)
    end

    def self.kill(error)
      WorkerManager.kill
      Process.kill(error)
    end

    def self.shutdown
      WorkerManager.shutdown
    end
  end
end
