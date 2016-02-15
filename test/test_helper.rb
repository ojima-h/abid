$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'abid'

require 'minitest/autorun'

class AbidTest < Minitest::Test
  def app
    @app ||= Abid::Application.new.tap do |app|
      app.init
      app.config['abid database'] = {
        'adapter' => 'sqlite',
        'database' => File.expand_path('../../tmp/abid.db', __FILE__),
        'max_connections' => 1
      }
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
