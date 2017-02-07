require 'test_helper'

module Abid
  class Engine
    class ProcessTest < AbidTest
      def test_new
        refute find_job('test_ok').process.complete?
        assert_equal :unscheduled, find_job('test_ok').process.status
      end

      def test_prepare
        process = find_job('test_ok').process
        assert process.prepare
        assert_equal :pending, process.status
        refute process.prepare
      end

      def test_start
        process = find_job('test_ok').process

        refute process.start, 'could not start before prepare'
        assert_equal :unscheduled, process.status

        assert process.prepare
        assert process.start
        assert_equal :running, process.status

        refute process.prepare, 'could not prepare after start'
      end

      def test_cancel
        process = find_job('test_ok').process

        refute process.cancel, 'could not cancel before prepare'
        assert_equal :unscheduled, process.status

        assert process.prepare
        assert process.cancel
        assert_equal :cancelled, process.status

        refute process.prepare, 'could not prepare after cancel'
      end

      def test_finish
        process = find_job('test_ok').process

        refute process.finish, 'could not finish before prepare'
        assert_equal :unscheduled, process.status

        assert process.prepare
        refute process.finish, 'could not finish before start'

        assert process.start
        assert process.finish
        assert_equal :successed, process.status

        refute process.start, 'could not start after finish'
      end

      def test_fail
        process = find_job('test_ok').process

        assert process.prepare
        assert process.start
        assert process.finish(RuntimeError.new('test'))
        assert_equal :failed, process.status
        assert_equal 'test', process.error.message
      end

      def test_quit_after_finish
        process = find_job('test_ok').process
        process.prepare
        process.start
        process.finish(RuntimeError.new('test'))
        process.quit(RuntimeError.new('quit'))

        assert_equal :failed, process.status
        assert_equal 'quit', process.error.message
      end

      def test_exception
        invoke('test_exception:p2')

        assert env.engine.worker_manager.each_worker.all?(&:shutdown?)
        %w(p1_1 p1_2 p2).each do |name|
          process = find_job("test_exception:#{name}", {}).process
          assert process.failed?
          assert_kind_of Exception, process.error
          assert_equal 'test', process.error.message
        end
      end
    end
  end
end
