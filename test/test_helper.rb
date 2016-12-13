$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'abid'

require 'minitest/autorun'

Abid::Config.search_path.unshift File.expand_path('../abid.yml', __FILE__)

class AbidTest < Minitest::Test
  def app
    @app ||= Abid::Application.new.tap do |app|
      app.init
      app.top_level_tasks.clear
      Abid.application = app
    end
  end

  def run(*args, &block)
    Rake.stub(:application, app) do
      # app.options.trace = true
      # app.options.backtrace = true
      # Rake.verbose(true)

      Abid::StateManager.database[:states].delete
      Abid::Job.clear_cache
      super
    end
  end

  def mock_state(*args)
    job = Abid::Job[*args]
    state = Abid::StateManager::State.init_by_job(job)
    yield state if block_given?
    state.state ||= Abid::StateManager::State::SUCCESSED
    state.start_time ||= Time.now
    state.end_time ||= Time.now
    state.tap(&:save)
  end
end
