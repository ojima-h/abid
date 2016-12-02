require 'test_helper'

module Abid
  module StateManager
    class StateTest < AbidTest
      def test_state
        state = State.create(name: 'name', params: '', digest: '')

        refute state.running? || state.successed? || state.failed?

        state.update(state: State::RUNNING)
        assert state.running?

        state.update(state: State::SUCCESSED)
        assert state.successed?

        state.update(state: State::FAILED)
        assert state.failed?
      end

      def test_check_running
        state = State.create(name: 'name', params: '', digest: '')

        state.check_running!

        state.update(state: State::RUNNING)
        assert_raises AlreadyRunningError do
          state.check_running!
        end
      end

      def test_find_by_job
        job1 = Job.new('name', a: 1)
        state1 = State.create(name: job1.name, params: job1.params_str, digest: job1.digest)

        job2 = Job.new('name', a: 2)
        State.create(name: job2.name, params: job2.params_str, digest: job2.digest)

        found = State.find_by_job(job1)
        assert_equal state1.id, found.id
      end

      def test_assume
        job = Job.new('name', b: 1, a: Date.new(2000, 1, 1))

        # Non-existing job
        state = State.assume(job)
        assert_equal 'name', state.name
        assert_equal "---\n:a: 2000-01-01\n:b: 1\n", state.params
        assert_equal job.digest, state.digest
        assert state.successed?

        # Failed job
        state.update(state: State::FAILED)
        state2 = State.assume(job)
        assert_equal state.id, state2.id
        assert_equal "---\n:a: 2000-01-01\n:b: 1\n", state2.params
        assert_equal job.digest, state2.digest
        assert state2.successed?

        # Running job
        state.update(state: State::RUNNING)
        assert_raises AlreadyRunningError do
          State.assume(job)
        end
        state3 = State.assume(job, force: true)
        assert_equal state.id, state3.id
        assert_equal "---\n:a: 2000-01-01\n:b: 1\n", state3.params
        assert_equal job.digest, state3.digest
        assert state3.successed?
      end
    end
  end
end
