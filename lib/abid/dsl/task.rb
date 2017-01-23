require 'rake/task'

module Abid
  module DSL
    # `play` task is defined as an instance of Abid::DSL::Task.
    #
    #     play(:foo) { ... } #=> #<Abid::DSL::Task ...>
    #
    class Task < Rake::Task
      attr_reader :internal

      def initialize(*args)
        super
        initialize_internal
      end

      def initialize_internal
        @internal = Play.create(self)
      end

      def enhance(deps = nil, &block)
        @internal.module_eval(&block) if block_given?
        super(deps)
      end

      def clear
        @internal_definitions.clear
        initialize_internal
        super
      end

      def bind(params = {})
        AbidTaskInstance.new(self, params)
      end

      def params_spec
        internal.params_spec
      end
    end

    # `mixin` task is defined as an instance of Abid::DSL::MixinTask.
    #
    #     mixin(:foo) { ... } #=> #<Abid::DSL::MixinTask ...>
    #
    class MixinTask < Task
      def initialize_internal
        @internal = Mixin.create(self)
      end

      def bind(*_args)
        raise 'mixin is not executable'
      end
    end
  end
end
