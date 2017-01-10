module Abid
  # Engine module operates task execution.
  module Engine
    def self.invoke(*args)
      Scheduler.invoke(*args)
    end

    def self.kill(error)
      Abid.global.worker_manager.kill
      Abid.global.process_manager.kill(error)
    end

    def self.shutdown
      Abid.global.worker_manager.shutdown
    end
  end
end
