$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'abid'

require 'minitest/autorun'

Abid::Config.search_path.unshift File.expand_path('../abid.yml', __FILE__)
Concurrent.use_stdlib_logger(Logger::DEBUG)

class AbidTest < Minitest::Test
  attr_reader :env

  def self.history
    @history ||= []
  end

  def run(*args, &block)
    Abid.global = Abid::Environment.new
    @env = Abid.global
    @env.application.init

    AbidTest.history.clear
    load File.expand_path('../Abidfile.rb', __FILE__)

    @env.state_manager.db[:states].delete
    super
  ensure
    @env.worker_manager.shutdown
  end

  def mock_state(name, params = {})
    signature = Abid::Signature.new(name, params)
    s = env.state_manager.states.init_by_signature(signature)
    t = Time.now
    s.set(state: Abid::StateManager::State::SUCCESSED,
          start_time: t, end_time: t)
    yield s if block_given?
    s.tap(&:save)
  end

  def mock_fail_state(name, params = {})
    mock_state(name, params) do |s|
      s.state = Abid::StateManager::State::FAILED
      yield s if block_given?
    end
  end

  def mock_running_state(name, params = {})
    mock_state(name, params) do |s|
      s.state = Abid::StateManager::State::RUNNING
      yield s if block_given?
    end
  end

  def in_repair_mode
    original_flag = Abid.application.options.repair
    Abid.application.options.repair = true
    yield
  ensure
    Abid.application.options.repair = original_flag
  end

  # empty Rake::TaskArguments
  def empty_args
    Rake::TaskArguments.new([], [])
  end
end
