require 'test_helper'

module Abid
  module Engine
    class ProcessTest < AbidTest
      def test_new
        refute Job['test_ok'].process.complete?
        assert_equal :unscheduled, Job['test_ok'].process.status
      end

      def test_prepare
        process = Job['test_ok'].process
        assert process.prepare
        assert_equal :pending, process.status
        refute process.prepare
      end

      def test_start
        process = Job['test_ok'].process

        refute process.start, 'could not start before prepare'
        assert_equal :unscheduled, process.status

        assert process.prepare
        assert process.start
        assert_equal :running, process.status

        refute process.prepare, 'could not prepare after start'
      end

      def test_cancel
        process = Job['test_ok'].process

        refute process.cancel, 'could not cancel before prepare'
        assert_equal :unscheduled, process.status

        assert process.prepare
        assert process.cancel
        assert_equal :complete, process.status
        assert process.cancelled?

        refute process.prepare, 'could not prepare after cancel'
      end

      def test_finish
        process = Job['test_ok'].process

        refute process.finish, 'could not finish before prepare'
        assert_equal :unscheduled, process.status

        assert process.prepare
        refute process.finish, 'could not finish before start'

        assert process.start
        assert process.finish
        assert_equal :complete, process.status
        assert process.successed?

        refute process.start, 'could not start after finish'
      end

      def test_fail
        process = Job['test_ok'].process

        assert process.prepare
        assert process.start
        assert process.finish(RuntimeError.new('test'))
        assert_equal :complete, process.status
        assert process.failed?
        assert_equal 'test', process.error.message
      end
    end
  end
end
