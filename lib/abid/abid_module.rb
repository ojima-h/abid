module Abid
  extend Rake

  class << self
    def application
      return @application if @application
      self.application = Abid::Application.new
    end

    def application=(app)
      @application = app
      Rake.application = app
    end
  end
end
