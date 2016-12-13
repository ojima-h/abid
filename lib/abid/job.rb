module Abid
  # Job instance that is consists of a task name and params.
  class Job
    attr_reader :name, :params

    # @param task [Rake::Task]
    # @return job [Job]
    def self.new_by_task(task)
      params = task.respond_to?(:params) ? task.params : {}
      new(task.name, params, task: task)
    end

    # @param name [String] task name
    # @param params [Hash] task params
    # @param task [Rake::Task] task object
    def initialize(name, params, task: nil)
      @name = name
      @params = params.sort.to_h.freeze
      @task = task
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

    # Update the state to SUCCESSED / FAILED
    def finish(error = nil)
      return if dryrun? || volatile?
      StateManager::State.finish(self, error)
    end

    def assume(force: false)
      StateManager::State.assume(self, force: force)
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
