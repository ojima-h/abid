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
        params_spec[name] = { significant: true }.merge(param_spec)

        define_method(name) { params[name] }
      end

      def hooks
        @hooks ||= {
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

      def before(&block)
        (hooks[:before] ||= []) << block
      end

      def after(&block)
        (hooks[:after] ||= []) << block
      end

      def around(&block)
        (hooks[:around] ||= []) << block
      end
    end

    set :worker, :default
    set :volatile, false

    extend Forwardable
    def_delegators :task, :application, :name, :scope
    def_delegators 'self.class', :params_spec

    attr_reader :prerequisites
    attr_reader :params

    def initialize(params)
      @prerequisites = []

      @params = ParamsParser.parse(params, params_spec)
      @params = @params.sort.to_h # avoid ambiguity of keys order
      @params.freeze
    end

    def task
      self.class.task
    end

    def setup
      # noop
    end

    def run
      # noop
    end

    def needs(task_name, **params)
      @prerequisites |= [[task_name, params]]
    end

    def significant_params
      [
        name,
        params.select { |p, _| params_spec[p][:significant] }
      ]
    end

    def hash
      significant_params.hash
    end

    def eql?(other)
      other.is_a?(Abid::Play) && \
        significant_params.eql?(other.significant_params)
    end

    def volatile?
      volatile
    end

    def preview?
      application.options.preview
    end

    def invoke
      self.class.hooks[:before].each { |blk| instance_eval(&blk) }

      call_around_hooks(self.class.hooks[:around]) { run }

      self.class.hooks[:after].each { |blk| instance_eval(&blk) }
    end

    def call_around_hooks(hooks, &body)
      if hooks.empty?
        body.call
      else
        h, *rest = hooks
        instance_exec(-> { call_around_hooks(rest, &body) }, &h)
      end
    end
    private :call_around_hooks
  end
end
