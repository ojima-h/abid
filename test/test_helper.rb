require 'abid'
require 'concurrent/configuration'
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
    init_app

    AbidTest.history.clear
    @env.state_manager.db[:states].delete

    load File.expand_path('../Abidfile.rb', __FILE__)
    super
  ensure
    @env.engine.kill(RuntimeError.new('premature end of test'))
  end

  def init_app
    @env.application.init
    @env.application.options.logging = false
    @env.application.options.summary = false
  end

  def mock_state(name, params = {})
    s = env.state_manager.state(name, params).find
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

  def invoke(*args)
    env.engine.invoke(*args)
  end

  def find_job(name, params = {})
    task = env.application.abid_tasks[name, params]
    env.engine.jobs[task]
  end

  def in_options(opts)
    orig = opts.map { |k, _| [k, env.application.options[k]] }
    opts.each { |k, v| env.application.options[k] = v }
    yield
  ensure
    orig.each { |k, v| env.application.options[k] = v }
  end

  # empty Rake::TaskArguments
  def empty_args
    Rake::TaskArguments.new([], [])
  end
end
