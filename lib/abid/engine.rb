require 'forwardable'

require 'abid/engine/executor'
require 'abid/engine/process_manager'
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
      @process_manager = ProcessManager.new(self)
      @worker_manager = WorkerManager.new(self)
    end
    attr_reader :process_manager, :worker_manager
    def_delegators :@env, :options, :state_manager, :logger
    def_delegators :process_manager, :summary, :errors

    # @param name [String] task name
    # @param params [Hash]
    # @param args [Array]
    # @return [(Symbol, Exception)] pair of result and error.
    def invoke(name, *args, **params)
      task = @env.application.abid_tasks[name, params]
      process_manager.invoke(task, args)
    end

    def kill(error)
      worker_manager.kill
      process_manager.kill(error)
    end

    def shutdown
      process_manager.shutdown
      worker_manager.shutdown
    end
  end
end
