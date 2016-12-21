require 'monitor'

module Abid
  # Job instance that is consists of a task name and params.
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

    def state
      if volatile?
        StateManager::State.init_by_job(self).tap(&:freeze)
      else
        StateManager::State.find_or_init_by_job(self).tap(&:freeze)
      end
    end

    # Update the state to RUNNING
    def start
      return if dryrun? || volatile?
      StateManager::State.start(self)
    end

    def try_start
      start
      true
    rescue AlreadyRunningError
      false
    end

    # Update the state to SUCCESSED / FAILED
    def finish(error = nil)
      return if dryrun? || volatile?
      StateManager::State.finish(self, error)
    end

    def assume(force: false)
      StateManager::State.assume(self, force: force)
    end

    # for testing
    def mock_fail(error)
      start
      finish(error)
    end

    private

    def volatile?
      task.volatile? || Abid.application.options.disable_state
    end

    def dryrun?
      Abid.application.options.dryrun || Abid.application.options.preview
    end
  end
end
