require 'monitor'

module Abid
  extend MonitorMixin

  class << self
    def config
      @config ||= Config.new
    end

    def global
      @global ||= Environment.new
    end
    attr_writer :global

    def application
      global.application
    end
  end
end

# Delegate Rake.application to Abid.global.application
class << Rake
  def application
    Abid.global.application
  end

  def application=(app)
    Abid.global.application = app
  end
end
