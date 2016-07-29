module Abid
  class MixinTask < Rake::Task
    class Mixin < Module
      include PlayCore
    end

    attr_accessor :mixin_definition

    def mixin
      @mixin ||= Mixin.new(&mixin_definition)
    end

    def execute(_args = nil)
      fail 'mixin is not executable'
    end

    class <<self
      def define_mixin(*args, &block) # :nodoc:
        Rake.application.define_mixin(self, *args, &block)
      end
    end
  end
end
