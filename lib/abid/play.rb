require 'forwardable'

module Abid
  class Play
    extend PlayCore

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
        @hooks ||= Hash.new { |h, k| h[k] = [] }
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
