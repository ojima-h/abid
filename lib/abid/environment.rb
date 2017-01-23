require 'monitor'

module Abid
  class Environment
    def initialize
      @mon = Monitor.new
    end

    def application
      @application ||= Abid::Application.new(self)
    end
    attr_writer :application

    def options
      application.options
    end

    def config
      return @config if @config
      @mon.synchronize do
        @cofig ||= Config.new
      end
    end

    def engine
      return @engine if @engine
      @mon.synchronize do
        @engine ||= Engine.new(self)
      end
    end

    def state_manager
      return @state_manager if @state_manager
      @mon.synchronize do
        @state_manager ||= StateManager.new(self)
      end
    end
  end
end
