module Abid
  module DSL
    # Common methods for Play and Mixin
    module PlayCore
      attr_reader :prerequisite_tasks
      attr_reader :params

      def needs(task_name, **params)
        t = task.application[task_name, @scope_in_actions]
        (@prerequisite_tasks ||= []) << [t, self.params.merge(params)]
      end

      def run
        # noop
      end

      def task
        self.class.task
      end

      def call_action(tag, *args)
        self.class.actions[tag].each do |scope, block|
          @scope_in_actions = scope
          instance_exec(*args, &block)
        end
      ensure
        @scope_in_actions = nil
      end

      def eval_setting(value = nil, &block)
        return instance_exec(&value) if value.is_a? Proc
        return value unless value.nil?
        return instance_exec(&block) if block_given?
        true
      end
      private :eval_setting

      module ClassMethods
        attr_reader :task

        def params_spec
          @params_spec ||= ParamsSpec.new(self)
        end

        def actions
          @actions ||= Actions.new(self)
        end

        def helpers(*extensions, &block)
          @helpers ||= Module.new
          @helpers.module_eval(&block) if block_given?
          @helpers.module_eval { include(*extensions) } if extensions.any?
          @helpers
        end

        def set(name, value = nil, &block)
          var = :"@#{name}"

          params_spec.delete(name) # undef param
          define_method(name) do
            unless instance_variable_defined?(var)
              val = eval_setting(value, &block)
              instance_variable_set(var, val)
            end
            instance_variable_get(var)
          end
        end

        def param(name, **spec)
          define_method(name) do
            raise NoParamError, "undefined param `#{name}' for #{task.name}" \
              unless params.include?(name)
            params[name]
          end
          params_spec[name] = spec
        end

        def undef_param(name)
          params_spec.delete(name)
        end

        #
        # Actions
        #
        def self.define_action(name)
          define_method(name) do |&block|
            actions.add(name, task.scope, block)
          end
        end
        define_action :setup
        define_action :after

        def include(*mod)
          ms = mod.map { |m| resolve_mixin(m) }
          super(*ms)
        end
        private :include

        def resolve_mixin(mod)
          return mod if mod.is_a? Module

          mixin_task = task.application[mod.to_s, task.scope]
          raise "#{mod} is not a mixin" unless mixin_task.is_a? MixinTask

          mixin_task.internal
        end
        private :resolve_mixin

        def superplays
          ancestors.select { |o| o.is_a? PlayCore::ClassMethods }
        end
      end
    end
  end
end
