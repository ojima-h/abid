require 'forwardable'
require 'monitor'

module Abid
  class Environment
    extend Forwardable

    def initialize
      @mon = Monitor.new
    end

    def application
      @application ||= Abid::Application.new(self)
    end
    attr_writer :application
    def_delegators :application, :options, :logger

    def config
      return @config if @config
      @mon.synchronize { @cofig ||= Config.new }
    end

    def engine
      return @engine if @engine
      @mon.synchronize { @engine ||= Engine.new(self) }
    end

    def state_manager
      return @state_manager if @state_manager
      @mon.synchronize { @state_manager ||= StateManager.new(self) }
    end
  end
end
