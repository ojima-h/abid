module Abid
  class MixinTask < Rake::Task
    class Mixin < Module
      include PlayCore
      attr_reader :task

      def initialize(task, *args, &block)
        @task = task
        super(*args, &block)
      end
    end

    attr_accessor :mixin_definition

    def mixin
      @mixin ||= Mixin.new(self, &mixin_definition)
    end

    def execute(_args = nil)
      raise 'mixin is not executable'
    end

    class <<self
      def define_mixin(*args, &block) # :nodoc:
        Abid.application.define_mixin(self, *args, &block)
      end
    end
  end
end
