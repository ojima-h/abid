module Abid
  class Environment
    def process_manager
      @process_manager ||= Engine::ProcessManager.new(self)
    end
  end
end
