module Abid
  # Job instance that is consists of a task name and params.
  class Job
    attr_reader :name, :params

    # @param name [String] task name
    # @param params [Hash] task params
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

    def state
      @state ||= StateManager::State.find_by_job(self) || \
                 StateManager::State.init_by_job(self)
    end
  end
end
