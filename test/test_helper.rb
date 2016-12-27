$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'abid'

require 'minitest/autorun'

Abid::Config.search_path.unshift File.expand_path('../abid.yml', __FILE__)

class AbidTest < Minitest::Test
  def self.history
    @history ||= []
  end

  def run(*args, &block)
    Abid.application = Abid::Application.new
    Abid.application.init
    Abid.application.top_level_tasks.clear

    # Abid.application.options.trace = true
    # Abid.application.options.backtrace = true
    # Rake.verbose(true)

    Abid::StateManager.database[:states].delete
    Abid::Job.clear_cache
    AbidTest.history.clear
    Abid::Engine::Process.active.clear
    Abid::Engine::WorkerManager.instance = Abid::Engine::WorkerManager.new

    load File.expand_path('../Abidfile.rb', __FILE__)
    super
  ensure
    Abid::Engine::WorkerManager.shutdown
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

  def in_repair_mode
    original_flag = Abid.application.options.repair
    Abid.application.options.repair = true
    yield
  ensure
    Abid.application.options.repair = original_flag
  end
end
