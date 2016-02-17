module Abid
  module DSL
    def play(*args, &block)
      Abid::Task.define_play(*args, &block)
    end

    def define_worker(name, thread_count)
      Rake.application.worker.define(name, thread_count)
    end

    def play_base(&block)
      Rake.application.play_base(&block)
    end

    def helpers(*extensions, &block)
      Abid::Play.helpers(*extensions, &block)
    end
  end
end

extend Abid::DSL
