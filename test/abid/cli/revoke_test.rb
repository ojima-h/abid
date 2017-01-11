require 'test_helper'
require 'abid/cli/revoke'

module Abid
  class CLI
    class RevokeTest < AbidTest
      def test_run
        states = Array.new(10) { |i| mock_state("job#{i}", i: i) }

        Revoke.new(env, { quiet: true }, states[3..5].map(&:id)).run

        assert_equal 7, env.db.states.count

        # force option
        state = states.first
        state.update(state: StateManager::State::RUNNING)

        Revoke.new(env, { quiet: true }, [state.id]).run
        refute_nil env.db.states[state.id]

        Revoke.new(env, { quiet: true, force: true }, [state.id]).run
        assert_nil env.db.states[state.id]
      end
    end
  end
end
