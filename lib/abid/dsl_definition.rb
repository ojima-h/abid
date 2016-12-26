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

    def invoke(task, *args, **params)
      Engine.invoke(Job.find_by_task(Abid.application[task, **params]), *args)
    end

    def mixin(*args, &block)
      Abid::MixinTask.define_mixin(*args, &block)
    end
  end
end

extend Abid::DSL
