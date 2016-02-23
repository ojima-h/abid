require 'test_helper'

module Abid
  class StateTest < AbidTest
    include Abid::DSL

    def setup
      play(:test) do
        param :date, type: :date

        setup do
          needs :parent
        end
      end

      play(:volatile) do
        set :volatile, true
      end
    end

    def test_find
      task = Rake.application['test', nil, date: '2000-01-01']
      state = State.find(task)
      state.start_session
      assert_equal state.id, State.find(task).id
    end

    def test_session_success
      task = Rake.application['test', nil, date: '2000-01-01']

      state = State.find(task)

      assert_nil state.state

      state.start_session
      assert state.running?
      state.close_session

      assert state.successed?

      assert State.find(task).successed?
    end

    def test_session_failed
      task = Rake.application['test', nil, date: '2000-01-01']

      state = State.find(task)

      assert_nil state.state

      state.start_session && state.close_session(StandardError.new('test'))

      assert state.failed?

      assert State.find(task).failed?
    end

    def test_volatile
      task = Rake.application['volatile', nil]

      state = State.find(task)

      assert_nil state.state
      assert state.disabled?

      state.start_session && state.close_session

      refute State.find(task).successed?
    end

    def test_running_error
      task = Rake.application['test', nil, date: '2000-01-01']
      state = State.find(task)
      state.start_session
      refute state.start_session, 'failed to open session'
      state.close_session

      task = Rake.application['volatile']
      state = State.find(task)
      state.start_session
      assert state.start_session, 'successed to open session'
    end

    def test_list
      task = Rake.application['test', nil, date: '2000-01-01']
      state = State.find(task)
      state.start_session && state.close_session

      states = State.list(started_after: Time.now - 60)
      assert 1, states.length
      assert({ date: Date.new(2000, 1, 1) }, states.first[:params])
      assert_equal :SUCCESSED, states.first[:state]
    end

    def test_revoke
      task_1 = Rake.application['test', nil, date: '2000-01-01']
      state_1 = State.find(task_1)
      state_1.start_session && state_1.close_session

      task_2 = Rake.application['test', nil, date: '2000-01-02']
      state_2 = State.find(task_2)
      state_2.start_session && state_2.close_session

      assert_equal 2, State.list.length

      state_1.revoke

      assert_nil State.find(task_1).id
    end

    def test_assume
      task = Rake.application['test', nil, date: '2000-02-01']
      state = State.find(task)
      state.assume

      state.reload
      assert state.successed?
    end
  end
end
