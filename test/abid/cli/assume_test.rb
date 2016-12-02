require 'test_helper'
require 'abid/cli/assume'

module Abid
  class CLI
    class AssumeTest < AbidTest
      def test_run
        Assume.new({}, %w(foo bar a=1 b=2000-01-01)).run

        state1 = StateManager::State.where(name: 'foo').first
        assert_equal "---\n:a: 1\n:b: 2000-01-01\n", state1.params

        state2 = StateManager::State.where(name: 'bar').first
        assert_equal "---\n:a: 1\n:b: 2000-01-01\n", state2.params

        # run again
        Assume.new({}, %w(foo a=1 b=2000-01-01)).run
        assert_equal 1, StateManager::State.where(name: 'foo').count

        # force option
        state1.update(state: StateManager::State::RUNNING)
        assert_raises(AlreadyRunningError) do
          Assume.new({}, %w(foo bar a=1 b=2000-01-01)).run
        end
        Assume.new({ force: true }, %w(foo bar a=1 b=2000-01-01)).run
        assert StateManager::State.where(name: 'foo').first.successed?
      end
    end
  end
end
