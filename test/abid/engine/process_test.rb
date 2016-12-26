require 'test_helper'

module Abid
  module Engine
    class ProcessTest < AbidTest
      def test_new
        refute Job['test_ok'].process.complete?
        assert_equal :unscheduled, Job['test_ok'].process.status
      end

      def test_execute_ok
        process = Job['test_ok'].process
        assert process.prepare
        assert process.start
        process.wait
        assert process.successed?
        assert_equal :complete, process.status
        assert_includes AbidTest.history, ['test_ok']
      end

      def test_execute_ng
        process = Job['test_ng'].process
        assert process.prepare
        assert process.start
        process.wait
        assert process.failed?
        assert_equal :complete, process.status
        assert_equal 'ng', process.error.message
        assert_includes AbidTest.history, ['test_ng']
      end

      def test_cancel_in_prepare
        Job['test_ok'].state.mock_fail(RuntimeError.new('test'))
        process = Job['test_ok'].process

        refute process.prepare
        assert process.cancelled?
        assert_equal :complete, process.status

        refute process.start
      end

      def test_skip_in_prepare
        Job['test_ok'].state.assume
        process = Job['test_ok'].process

        refute process.prepare
        assert process.skipped?
        assert_equal :complete, process.status

        refute process.start
      end

      def test_cancel_after_prerequsites
        job = Job['test_p2', i: 0]
        job.prerequisites.each do |p|
          p.process.quit(RuntimeError.new('test'))
        end

        process = job.process
        assert process.prepare
        refute process.start
        assert process.cancelled?
        assert_equal :complete, process.status
      end

      def test_prepare_after_running
        process = Job['test_ok'].process
        process.send(:compare_and_set_status, :running, :unscheduled)
        refute process.prepare
      end

      def test_start_twice
        process = Job['test_ok'].process
        assert process.prepare
        assert process.start
        process.wait
        assert process.successed?

        process2 = Job['test_ok'].process
        refute process2.prepare
        refute process2.start
      end

      def test_execute_running
        Job['test_ok'].state.start

        process = Job['test_ok'].process
        process.prepare
        process.start
        process.wait
        assert process.failed?
        assert_equal :complete, process.status
        assert_kind_of AlreadyRunningError, process.error
      end
    end
  end
end
