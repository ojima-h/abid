$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'abid'

require 'minitest/autorun'

class AbidTest < Minitest::Test
  def app
    @app ||= Abid::Application.new.tap do |app|
      app.init
      Abid.config.database.replace(
        'adapter' => 'sqlite',
        'database' => File.expand_path('../../tmp/abid.db', __FILE__),
        'max_connections' => 1
      )
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
