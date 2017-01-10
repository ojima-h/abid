require 'abid/rake_extensions/task'

# Delegate Rake.application to Abid.global.application
class << Rake
  def application
    Abid.global.application
  end

  def application=(app)
    Abid.global.application = app
  end
end

Rake::Task.include Abid::RakeExtensions::Task
