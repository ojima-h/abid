require 'monitor'

module Abid
  extend MonitorMixin

  class << self
    def application
      @application ||= Abid::Application.new
    end

    attr_writer :application

    def config
      @config ||= Config.new
    end
  end
end

# Delegate Rake.application to Abid.application
class << Rake
  def application
    Abid.application
  end

  def application=(app)
    Abid.application = app
  end
end
