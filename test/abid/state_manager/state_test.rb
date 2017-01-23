require 'test_helper'

module Abid
  class StateManager
    class StateTest < AbidTest
      def states
        env.state_manager.states
      end

      def find_state(name, params)
        env.state_manager.state(name, params).find
      end

      def test_state
        s = states.create(name: 'name', params: '', digest: '')

        refute s.running? || s.successed? || s.failed?

        s.update(state: State::RUNNING)
        assert s.running?

        s.update(state: State::SUCCESSED)
        assert s.successed?

        s.update(state: State::FAILED)
        assert s.failed?
      end

      def test_check_running
        s = states.create(name: 'name', params: '', digest: '')

        s.check_running!

        s.update(state: State::RUNNING)
        assert_raises AlreadyRunningError do
          s.check_running!
        end
      end

      def test_find
        s1 = mock_state('name', a: 1)
        mock_state('name', a: 2)

        found = env.state_manager.state('name', a: 1).find
        assert_equal s1.id, found.id
      end

      def test_start
        # Non-existing job
        args = ['name', b: 1, a: Date.new(2000, 1, 1)]
        find_state(*args).start

        state = find_state(*args)
        assert_equal 'name', state.name
        assert_equal "---\n:a: 2000-01-01\n:b: 1\n", state.params
        assert state.running?
      end

      def test_start_failed
        # Failed job
        args = ['name', b: 1, a: Date.new(2000, 1, 1)]
        mock_fail_state(*args)
        find_state(*args).start

        assert find_state(*args).running?
      end

      def test_start_running
        # Running job
        args = ['name', b: 1, a: Date.new(2000, 1, 1)]
        mock_running_state(*args)

        assert_raises AlreadyRunningError do
          find_state(*args).start
        end
      end

      def test_finish
        # Non-existing job
        args = ['name', b: 1, a: Date.new(2000, 1, 1)]
        find_state(*args).finish
        assert find_state(*args).new?
      end

      def test_finish_failed
        args = ['name', b: 1, a: Date.new(2000, 1, 1)]
        mock_fail_state(*args)

        # Failed job
        find_state(*args).finish
        assert find_state(*args).failed? # do nothing
      end

      def test_finish_running
        args = ['name', b: 1, a: Date.new(2000, 1, 1)]
        mock_running_state(*args)

        # Running job
        find_state(*args).finish
        assert find_state(*args).successed?
      end

      def test_finish_running_with_error
        args = ['name', b: 1, a: Date.new(2000, 1, 1)]
        mock_running_state(*args)

        # With an error
        find_state(*args).finish(StandardError.new)
        assert find_state(*args).failed?
      end

      def test_assume
        args = ['name', b: 1, a: Date.new(2000, 1, 1)]

        # Non-existing job
        find_state(*args).assume
        state = find_state(*args)
        assert_equal 'name', state.name
        assert_equal "---\n:a: 2000-01-01\n:b: 1\n", state.params
        assert state.successed?
      end

      def test_assume_failed
        args = ['name', b: 1, a: Date.new(2000, 1, 1)]
        mock_fail_state(*args)

        # Failed job
        find_state(*args).assume
        assert find_state(*args).successed?
      end

      def test_assume_running
        args = ['name', b: 1, a: Date.new(2000, 1, 1)]
        mock_running_state(*args)

        # Running job
        assert_raises AlreadyRunningError do
          find_state(*args).assume
        end

        find_state(*args).assume(force: true)
        assert find_state(*args).successed?
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

        ss[0].revoke
        assert_nil states[ss[0].id]

        ss[1].update(state: State::RUNNING)
        assert_raises AlreadyRunningError do
          ss[1].revoke
        end
        ss[1].revoke(force: true)
        assert_nil states[ss[1].id]

        assert_equal 8, states.count
      end
    end
  end
end
