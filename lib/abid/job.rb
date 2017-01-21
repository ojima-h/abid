require 'forwardable'
require 'monitor'

module Abid
  # Job is an aggregation object of components around the task.
  class Job
    attr_reader :name, :params, :env

    class << self
      extend Forwardable
      def_delegators 'Abid.global.job_manager', :[], :find_by_task
    end

    # @!visibility private
    def initialize(env, name, params)
      @env = env
      @name = name
      @params = params.sort.to_h.freeze
      @mon = Monitor.new
      @root = false
    end

    def root?
      @root
    end

    def root
      @root = true
      self
    end

    def invoke(*args)
      Engine::Scheduler.invoke(self, *args)
      process.wait
    end

    def params_str
      @params_str ||= YAML.dump(params)
    end

    def digest
      @digest ||= Digest::MD5.hexdigest(name + "\n" + params_str)
    end

    def task
      @task ||= Abid.application[name].bind(params)
    end

    def state
      @state ||= StateManager::StateProxy.new(self)
    end

    def prerequisites
      task.prerequisite_tasks.map do |preq_task, params|
        env.job_manager.find_by_task(preq_task, params)
      end
    end

    def process
      @mon.synchronize do
        @process ||= env.process_manager.create
      end
    end

    def worker
      env.worker_manager[task.worker]
    end

    def volatile?
      task.volatile? || env.options.disable_state
    end

    def dryrun?
      env.options.dryrun || env.options.preview
    end
  end
end
