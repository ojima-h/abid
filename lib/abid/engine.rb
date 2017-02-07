require 'forwardable'

require 'abid/engine/executor'
require 'abid/engine/job'
require 'abid/engine/job_manager'
require 'abid/engine/process'
require 'abid/engine/scheduler'
require 'abid/engine/worker_manager'
require 'abid/engine/waiter'

module Abid
  # Engine module operates task execution.
  class Engine
    extend Forwardable

    def initialize(env)
      @env = env
      @job_manager = JobManager.new(self)
      @worker_manager = WorkerManager.new(self)
    end
    attr_reader :job_manager, :worker_manager
    alias jobs job_manager
    def_delegators :@env, :options, :state_manager, :logger
    def_delegators :job_manager, :summary, :pretty_summary, :errors

    end

    end

    def kill(error)
      worker_manager.kill
      job_manager.kill(error)
    end

    end
  end
end
