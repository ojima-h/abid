module Avid
  module DSL
    def play(*args, &block)
      Avid::Task.define_play(*args, &block)
    end

    def define_worker(name, thread_count)
      Rake.application.worker.define(name, thread_count)
    end

    def default_play_class(&block)
      Rake.application.default_play_class(&block)
    end

    def helpers(*extensions, &block)
      Avid::Play.helpers(*extensions, &block)
    end
  end
end

extend Avid::DSL
