# Delegate Rake.application to Abid.global.application
class << Rake
  def application
    Abid.global.application
  end

  def application=(app)
    Abid.global.application = app
  end
end

module Rake
  class Task
    def bind(params = {})
      Abid::DSL::RakeTaskInstance.new(self, params)
    end

    def resolve_params(_params)
      {}
    end
  end
end
