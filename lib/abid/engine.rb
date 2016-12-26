module Abid
  # Engine module operates task execution.
  module Engine
    def self.invoke(*args)
      Scheduler.invoke(*args)
    end

    def self.kill(error)
      Process.kill(error)
    end
  end
end
