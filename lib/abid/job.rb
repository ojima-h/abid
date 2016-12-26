require 'monitor'

module Abid
  # Job is an aggregation object of components around the task.
  class Job
    extend MonitorMixin

    attr_reader :name, :params

    def self.[](name, params = {})
      synchronize do
        @cache ||= {}
        key = [name, params.sort.freeze].freeze
        @cache[key] ||= new(name, params)
      end
    end

    def self.find_by_task(task)
      self[task.name, task.respond_to?(:params) ? task.params : {}]
    end

    def self.clear_cache
      synchronize do
        @cache = {}
      end
    end

    private_class_method :new

    # @!visibility private
    def initialize(name, params)
      @name = name
      @params = params.sort.to_h.freeze
    end

    def params_str
      @params_str ||= YAML.dump(params)
    end

    def digest
      @digest ||= Digest::MD5.hexdigest(name + "\n" + params_str)
    end

    def task
      @task ||= Abid.application[name, nil, params]
    end

    def state
      @state ||= StateManager::StateProxy.new(self)
    end

    def prerequisites
      task.prerequisite_tasks.map do |preq_task|
        Job.find_by_task(preq_task)
      end
    end

    def process
      Job.synchronize do
        @process ||= Engine::Process.new(self)
      end
    end

    def volatile?
      task.volatile? || Abid.application.options.disable_state
    end

    def dryrun?
      Abid.application.options.dryrun || Abid.application.options.preview
    end
  end
end
