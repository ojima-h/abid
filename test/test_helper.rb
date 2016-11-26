$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'abid'

require 'minitest/autorun'

Abid::Config.search_path.unshift File.expand_path('../abid.yml', __FILE__)

class AbidTest < Minitest::Test
  def app
    @app ||= Abid::Application.new.tap do |app|
      app.init
      app.top_level_tasks.clear
    end
  end

  def run(*args, &block)
    Rake.stub(:application, app) do
      # app.options.trace = true
      # app.options.backtrace = true
      # Rake.verbose(true)

      app.database[:states].delete
      super
    end
  end
end
