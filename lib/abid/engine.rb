require 'forwardable'

require 'abid/engine'
require 'abid/engine/executor'
require 'abid/engine/job'
require 'abid/engine/job_manager'
require 'abid/engine/process'
require 'abid/engine/process_manager'
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
      @process_manager = ProcessManager.new(self)
      @worker_manager = WorkerManager.new(self)
    end
    attr_reader :job_manager, :process_manager, :worker_manager
    alias jobs job_manager
    def_delegators :@env, :options, :state_manager

    def job(name, params)
      t = @env.application.abid_task_manager.resolve(name, params)
      jobs[t]
    end

    def invoke(name, params, args)
      job(name, params).invoke(*args)
    end

    def kill(error)
      worker_manager.kill
      process_manager.kill(error)
    end

    def shutdown
      worker_manager.shutdown
    end
  end
end
