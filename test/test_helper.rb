$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'avid'

require 'minitest/autorun'

class AvidTest < Minitest::Test
  def app
    @app ||= Avid::Application.new.tap do |app|
      app.init
      app.config['avid database'] = {
        'adapter' => 'sqlite',
        'database' => File.expand_path('../../tmp/avid.db', __FILE__),
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
