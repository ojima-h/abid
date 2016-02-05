$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'avid'

require 'minitest/autorun'

class AvidTest < Minitest::Test
  def app
    @app ||= Avid::Application.new.tap do |app|
      app.init
      app.config['avid']['database_url'] = 'sqlite://' + File.expand_path('../../tmp/avid.db', __FILE__)
    end
  end

  def run(*args, &block)
    Rake.stub(:application, app) do
      app.database[:states].delete

      super
    end
  end
end
