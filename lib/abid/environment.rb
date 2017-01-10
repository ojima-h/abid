require 'monitor'

module Abid
  class Environment
    def initialize
      @mon = Monitor.new
    end

    def application
      @application ||= Abid::Application.new(self)
    end
    attr_writer :application

    def options
      application.options
    end

    def config
      @mon.synchronize do
        @cofig ||= Config.new
      end
    end

    def job_manager
      @mon.synchronize do
        @job_manager ||= JobManager.new(self)
      end
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
