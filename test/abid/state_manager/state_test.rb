require 'test_helper'

module Abid
  module StateManager
    class StateTest < AbidTest
      def test_create
        name = 'name'
        params = { b: 1, a: Date.new(2000, 1, 1) }
        state = State.create(name: name, params: params)

        assert_equal ParamsFormat.digest(name, params), state.digest

        raw_params = StateManager.database.fetch(<<-SQL, state.id).first[:params]
        SELECT params FROM states WHERE id = ?
        SQL
        assert_equal "---\n:a: 2000-01-01\n:b: 1\n", raw_params
      end

      def test_state
        name = 'name'
        params = { b: 1, a: Date.new(2000, 1, 1) }
        state = State.create(name: name, params: params)

        refute state.running? || state.successed? || state.failed?

        state.update(state: State::RUNNING)
        assert state.running?

        state.update(state: State::SUCCESSED)
        assert state.successed?

        state.update(state: State::FAILED)
        assert state.failed?
      end

      def test_check_running
        name = 'name'
        params = { b: 1, a: Date.new(2000, 1, 1) }
        state = State.create(name: name, params: params)

        state.check_running!

        state.update(state: State::RUNNING)
        assert_raises AlreadyRunningError do
          state.check_running!
        end
      end
    end
  end
end
