require 'monitor'

module Abid
  class Environment
    def initialize
      @mon = Monitor.new
    end

    def process_manager
      @mon.synchronize do
        @process_manager ||= Engine::ProcessManager.new(self)
      end
    end

    def worker_manager
      @mon.synchronize do
        @worker_manager ||= Engine::WorkerManager.new(self)
      end
    end
  end
end
