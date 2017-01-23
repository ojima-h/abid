require 'test_helper'

module Abid
  class StateManager
    class StateTest < AbidTest
      def states
        env.state_manager.states
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

      def test_find_by_signature
        s1 = mock_state('name', a: 1)
        mock_state('name', a: 2)
        signature = Signature.new('name', a: 1)

        found = states.find_by_signature(signature)
        assert_equal s1.id, found.id
      end

      def test_start
        # Non-existing job
        sig = Signature.new('name', b: 1, a: Date.new(2000, 1, 1))
        states.init_by_signature(sig).start

        state = states.find_by_signature(sig)
        assert_equal 'name', state.name
        assert_equal "---\n:a: 2000-01-01\n:b: 1\n", state.params
        assert_equal sig.digest, state.digest
        assert state.running?
      end

      def test_start_failed
        # Failed job
        sig = Signature.new('name', b: 1, a: Date.new(2000, 1, 1))
        mock_fail_state(sig.name, sig.params)
        states.find_by_signature(sig).start

        assert states.find_by_signature(sig).running?
      end

      def test_start_running
        # Running job
        sig = Signature.new('name', b: 1, a: Date.new(2000, 1, 1))
        mock_running_state(sig.name, sig.params)

        assert_raises AlreadyRunningError do
          states.find_by_signature(sig).start
        end
      end

      def test_finish
        sig = Signature.new('name', b: 1, a: Date.new(2000, 1, 1))

        # Non-existing job
        states.init_by_signature(sig).finish
        assert_nil states.find_by_signature(sig)
      end

      def test_finish_failed
        sig = Signature.new('name', b: 1, a: Date.new(2000, 1, 1))
        mock_fail_state(sig.name, sig.params)

        # Failed job
        states.find_by_signature(sig).finish
        assert states.find_by_signature(sig).failed? # do nothing
      end

      def test_finish_running
        sig = Signature.new('name', b: 1, a: Date.new(2000, 1, 1))
        mock_running_state(sig.name, sig.params)

        # Running job
        states.find_by_signature(sig).finish
        assert states.find_by_signature(sig).successed?
      end

      def test_finish_running_with_error
        sig = Signature.new('name', b: 1, a: Date.new(2000, 1, 1))
        mock_running_state(sig.name, sig.params)

        # With an error
        states.find_by_signature(sig).finish(StandardError.new)
        assert states.find_by_signature(sig).failed?
      end

      def test_assume
        sig = Signature.new('name', b: 1, a: Date.new(2000, 1, 1))

        # Non-existing job
        states.init_by_signature(sig).assume
        state = states.find_by_signature(sig)
        assert_equal 'name', state.name
        assert_equal "---\n:a: 2000-01-01\n:b: 1\n", state.params
        assert_equal sig.digest, state.digest
        assert state.successed?
      end

      def test_assume_failed
        sig = Signature.new('name', b: 1, a: Date.new(2000, 1, 1))
        mock_fail_state(sig.name, sig.params)

        # Failed job
        states.find_by_signature(sig).assume
        assert states.find_by_signature(sig).successed?
      end

      def test_assume_running
        sig = Signature.new('name', b: 1, a: Date.new(2000, 1, 1))
        mock_running_state(sig.name, sig.params)

        # Running job
        assert_raises AlreadyRunningError do
          states.find_by_signature(sig).assume
        end

        states.find_by_signature(sig).assume(force: true)
        assert states.find_by_signature(sig).successed?
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
