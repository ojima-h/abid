require 'test_helper'

module Avid
  class StateTest < AvidTest
    include Avid::DSL

    def setup
      play(:test) do
        param :date, type: :date

        def setup
          needs :parent
        end
      end

      play(:volatile) do
        volatile
      end
    end

    def test_find
      task = Rake.application['test', nil, date: '2000-01-01']
      state = State.find(task)
      state.session {}
      assert_equal state.id, State.find(task).id
    end

    def test_session_success
      task = Rake.application['test', nil, date: '2000-01-01']

      state = State.find(task)

      assert_nil state.state

      state.session do
        assert state.running?
      end

      assert state.successed?

      assert State.find(task).successed?
    end

    def test_session_failed
      task = Rake.application['test', nil, date: '2000-01-01']

      state = State.find(task)

      assert_nil state.state

      assert_raises(StandardError) do
        state.session { fail 'test' }
      end

      assert state.failed?

      assert State.find(task).failed?
    end

    def test_volatile
      task = Rake.application['volatile', nil]

      state = State.find(task)

      assert_nil state.state
      assert state.volatile?

      state.session {}

      refute State.find(task).successed?
    end

    def test_running_error
      task = Rake.application['test', nil, date: '2000-01-01']
      state = State.find(task)
      assert_raises do
        state.session do
          state.session {}
        end
      end

      task = Rake.application['volatile']
      state = State.find(task)
      state.session do
        state.session {} # no exception
      end
    end

    def test_list
      task = Rake.application['test', nil, date: '2000-01-01']
      state = State.find(task)
      state.session {}

      states = State.list(started_after: Time.now - 60)
      assert 1, states.length
      assert({ date: Date.new(2000, 1, 1) }, states.first[:params])
      assert_equal :SUCCESSED, states.first[:state]
    end

    def test_revoke
      task_1 = Rake.application['test', nil, date: '2000-01-01']
      state_1 = State.find(task_1)
      state_1.session {}

      task_2 = Rake.application['test', nil, date: '2000-01-02']
      state_2 = State.find(task_2)
      state_2.session {}

      assert_equal 2, State.list.length

      state_1.revoke

      assert_equal State::REVOKED, State.find(task_1).state
    end
  end
end
