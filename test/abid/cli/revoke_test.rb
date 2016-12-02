require 'test_helper'
require 'abid/cli/revoke'

module Abid
  class CLI
    class RevokeTest < AbidTest
      def test_run
        states = Array.new(10) do |i|
          StateManager::State.assume(Job.new("job#{i}", i: i))
        end

        Revoke.new({ quiet: true }, states[3..5].map(&:id)).run

        assert_equal 7, StateManager::State.count

        # force option
        state = states.first
        state.update(state: StateManager::State::RUNNING)

        Revoke.new({ quiet: true }, [state.id]).run
        refute_nil StateManager::State[state.id]

        Revoke.new({ quiet: true, force: true }, [state.id]).run
        assert_nil StateManager::State[state.id]
      end
    end
  end
end
