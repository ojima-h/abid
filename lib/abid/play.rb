require 'forwardable'

module Abid
  class Play
    class << self
      attr_accessor :task

      def inherited(child)
        params_spec.each { |k, v| child.params_spec[k] = v.dup }
        hooks.each { |k, v| child.hooks[k] = v.dup }
      end

      def params_spec
        @params_spec ||= {}
      end

      def param(name, **param_spec)
        define_method(name) { task.params[name] }
        params_spec[name] = { significant: true }.merge(param_spec)
      end

      def undef_param(name)
        params_spec.delete(name)
        undef_method(name) if method_defined?(name)
      end

      def hooks
        @hooks ||= {
          setup: [],
          before: [],
          after: [],
          around: []
        }
      end

      def set(name, value = nil, &block)
        var = :"@#{name}"

        define_method(name) do
          unless instance_variable_defined?(var)
            if !value.nil?
              instance_variable_set(var, value)
            elsif block_given?
              instance_variable_set(var, instance_eval(&block))
            end
          end
          instance_variable_get(var)
        end
      end

      def helpers(*extensions, &block)
        class_eval(&block) if block_given?
        include(*extensions) if extensions.any?
      end

      def setup(&block)
        hooks[:setup] << block
      end

      def before(&block)
        hooks[:before] << block
      end

      def after(&block)
        hooks[:after] << block
      end

      def around(&block)
        hooks[:around] << block
      end

      def method_added(name)
        params_spec.delete(name) # undef param
      end
    end

    set :worker, :default
    set :volatile, false

    attr_reader :task

    def initialize(task)
      @task = task
    end

    def run
      # noop
    end

    def needs(task_name, **params)
      task.enhance([[task_name, params]])
    end

    def volatile?
      volatile
    end

    def preview?
      task.application.options.preview
    end
  end
end
