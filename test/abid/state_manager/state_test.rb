require 'test_helper'

module Abid
  module StateManager
    class StateTest < AbidTest
      def states
        env.db.states
      end

      def test_state
        state = states.create(name: 'name', params: '', digest: '')

        refute state.running? || state.successed? || state.failed?

        state.update(state: State::RUNNING)
        assert state.running?

        state.update(state: State::SUCCESSED)
        assert state.successed?

        state.update(state: State::FAILED)
        assert state.failed?
      end

      def test_check_running
        state = states.create(name: 'name', params: '', digest: '')

        state.check_running!

        state.update(state: State::RUNNING)
        assert_raises AlreadyRunningError do
          state.check_running!
        end
      end

      def test_find_by_job
        job1 = Job['name', a: 1]
        state1 = states.create(name: job1.name, params: job1.params_str, digest: job1.digest)

        job2 = Job['name', a: 2]
        states.create(name: job2.name, params: job2.params_str, digest: job2.digest)

        found = states.find_by_job(job1)
        assert_equal state1.id, found.id
      end

      def test_start
        job = Job['name', b: 1, a: Date.new(2000, 1, 1)]

        # Non-existing job
        states.start(job)
        state = states.find_by_job(job)
        assert_equal 'name', state.name
        assert_equal "---\n:a: 2000-01-01\n:b: 1\n", state.params
        assert_equal job.digest, state.digest
        assert state.running?

        # Failed job
        states[state.id].update(state: State::FAILED)
        states.start(job)
        assert states.find_by_job(job).running?

        # Running job
        states[state.id].update(state: State::RUNNING)
        assert_raises AlreadyRunningError do
          states.start(job)
        end
      end

      def test_finish
        job = Job['name', b: 1, a: Date.new(2000, 1, 1)]

        # Non-existing job
        states.finish(job)
        assert_nil states.find_by_job(job)

        # Failed job
        mock_state(job.name, job.params) { |s| s.state = State::FAILED }
        states.finish(job)
        assert states.find_by_job(job).failed? # do nothing

        # Running job
        states.start(job)
        states.finish(job)
        assert states.find_by_job(job).successed?

        # With an error
        states.start(job)
        states.finish(job, StandardError.new)
        assert states.find_by_job(job).failed?
      end

      def test_assume
        job = Job['name', b: 1, a: Date.new(2000, 1, 1)]

        # Non-existing job
        states.assume(job)
        state = states.find_by_job(job)
        assert_equal 'name', state.name
        assert_equal "---\n:a: 2000-01-01\n:b: 1\n", state.params
        assert_equal job.digest, state.digest
        assert state.successed?

        # Failed job
        states.find_by_job(job).update(state: State::FAILED)
        states.assume(job)
        assert_equal 1, states.where(digest: job.digest).count
        assert states.find_by_job(job).successed?

        # Running job
        states.find_by_job(job).update(state: State::RUNNING)
        assert_raises AlreadyRunningError do
          states.assume(job)
        end
        states.assume(job, force: true)
        assert_equal 1, states.where(digest: job.digest).count
        assert states.find_by_job(job).successed?
      end

      def test_filter
        ss = Array.new(10) do |i|
          mock_state("job#{i % 2}:foo#{i}", i: i) do |s|
            s.start_time = Time.new(2000, 1, 1, i)
            s.end_time = Time.new(2000, 1, 1, i + 1)
          end
        end

        found = states.filter_by_prefix('job0:')
                      .filter_by_start_time(
                        after: Time.new(2000, 1, 1, 3),
                        before: Time.new(2000, 1, 1, 8)
                      ).order(:id).to_a
        assert_equal 3, found.length
        assert_equal ss[4].id, found[0].id
        assert_equal ss[6].id, found[1].id
        assert_equal ss[8].id, found[2].id
      end

      def test_revoke
        ss = Array.new(10) { |i| mock_state('job', i: i) }

        states.revoke(ss[0].id)
        assert_nil states[ss[0].id]

        ss[1].update(state: State::RUNNING)
        assert_raises AlreadyRunningError do
          states.revoke(ss[1].id)
        end
        states.revoke(ss[1].id, force: true)
        assert_nil states[ss[1].id]

        assert_equal 8, states.count
      end
    end
  end
end
