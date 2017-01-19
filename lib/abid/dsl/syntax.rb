module Abid
  module DSL
    module Syntax
      def play(*args, &block)
        Task.define_task(*args, &block)
      end

      def mixin(*args, &block)
        MixinTask.define_task(*args, &block)
      end

      def define_worker(name, thread_count)
        Abid.global.worker_manager.define(name, thread_count)
      end

      def global_mixin(&block)
        Abid.application.global_mixin.class_eval(&block)
      end

      def invoke(task, *args, **params)
        Abid.global.job_manager.fetch(task, params).invoke(*args)
      end
    end
  end
end

extend Abid::DSL::Syntax
