module Avid
  class Play
    attr_reader :prerequisites
    attr_reader :params

    def initialize(params)
      @prerequisites = []
      @params = ParamsParser.parse(params, params_spec)
    end

    def setup
      # noop
    end

    def run
      # noop
    end

    def needs(task_name, **params)
      prerequisites << [task_name, params]
    end

    def invoke
      run
    end

    def hash
      @hash ||= [play_name, significant_params].hash
    end

    def significant_params
      params.select do |name, _|
        params_spec[name][:significant]
      end
    end

    class << self
      def new(args)
        super(args).tap(&:setup)
      end

      def param(name, **param_spec)
        params_spec[name] = { significant: true }.merge(param_spec)

        define_method(name) { params[name] }
      end

      def define_attribute(name, default = nil)
        attributes = (@attributes ||= {})
        attributes[name] = default

        define_singleton_method(name) do |value = nil|
          if value.nil?
            attributes[name]
          else
            attributes[name] = value
          end
        end

        define_method(name) { attributes[name] }
      end
    end

    define_attribute :application
    define_attribute :play_name
    define_attribute :scope
    define_attribute :worker
    define_attribute :params_spec, {}
  end
end
