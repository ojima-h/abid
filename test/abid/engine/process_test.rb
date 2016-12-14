require 'test_helper'

module Abid
  module Engine
    class ProcessTest < AbidTest
      def test_new
        refute Job['test_ok'].process.result.complete?
        assert_equal :unscheduled, Job['test_ok'].process.state
      end

      def test_execute
        assert Job['test_ok'].process.execute
        assert_equal :successed, Job['test_ok'].process.result.value(1)
        assert_equal :complete, Job['test_ok'].process.state
      end

      def test_execute_failed
        assert Job['test_ng'].process.execute
        assert_equal :failed, Job['test_ng'].process.result.value(1)
        assert_equal :complete, Job['test_ng'].process.state
      end

      def test_cancel
        assert Job['test_ok'].process.cancel
        assert_equal :cancelled, Job['test_ok'].process.result.value(1)
        assert_equal :complete, Job['test_ok'].process.state
        refute Job['test_ok'].process.cancel
      end

      def test_skip
        assert Job['test_ok'].process.skip
        assert_equal :skipped, Job['test_ok'].process.result.value(1)
        assert_equal :complete, Job['test_ok'].process.state
        refute Job['test_ok'].process.skip
      end

      def test_execute_completed
        assert Job['test_ok'].process.cancel
        refute Job['test_ok'].process.execute
      end

      def test_cancel_processing
        process = Job['test_ok'].process
        process.send(:compare_and_set_state, :processing, :unscheduled)
        refute Job['test_ok'].process.cancel
      end

      def test_execute_running
        Job['test_ok'].start

        Job['test_ok'].process.execute
        assert_equal :failed, Job['test_ok'].process.result.value(1)
        assert_equal :complete, Job['test_ok'].process.state
        assert_kind_of AlreadyRunningError, Job['test_ok'].process.error
      end
    end
  end
end
