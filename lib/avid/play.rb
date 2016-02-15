require 'forwardable'

module Avid
  class Play
    extend Forwardable
    def_delegators :task, :application, :name, :scope

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
      other.is_a?(Avid::Play) && \
        significant_params.eql?(other.significant_params)
    end

    def preview?
      application.options.preview
    end

    class << self
      attr_accessor :task

      def inherited(child)
        attributes.each { |k, v| child.attributes[k] = v.dup }
        params_spec.each { |k, v| child.params_spec[k] = v.dup }
      end

      def param(name, **param_spec)
        params_spec[name] = { significant: true }.merge(param_spec)

        define_method(name) { params[name] }
      end

      def attributes
        @attributes ||= {}
      end

      def define_attribute(name, &default)
        define_singleton_method(name) do |value = nil|
          attributes[name] ||= default.call if block_given?

          if value.nil?
            attributes[name]
          else
            attributes[name] = value
          end
        end

        define_method(name) { self.class.send(name) }
      end

      def volatile(v = true)
        @volatile = v
      end

      def volatile?
        @volatile
      end

      def helpers(*extensions, &block)
        class_eval(&block) if block_given?
        include(*extensions) if extensions.any?
      end
    end

    define_attribute :worker
    define_attribute(:params_spec) { Hash.new }
  end
end
