require 'monitor'

module Abid
  class JobManager
    def initialize(env)
      @env = env
      @cache = {}
      @mon = Monitor.new
    end

    def [](name, params = {})
      @mon.synchronize do
        key = [name, params.sort.freeze].freeze
        @cache[key] ||= Job.new(@env, name, params)
      end
    end

    def find_by_task(task, params = {})
      params = @env.application.abid_task_manager.resolve_params(task, params)
      self[task.name, params]
    end
  end
end
