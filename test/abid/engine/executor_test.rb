require 'test_helper'

module Abid
  class Engine
    class ExecutorTest < AbidTest
      def test_execute_ok
        job = find_job('test_ok')
        executor = Executor.new(job, empty_args)
        assert executor.prepare
        assert executor.start
        job.process.wait
        assert job.process.successed?
        assert_includes AbidTest.history, ['test_ok']
      end

      def test_execute_ng
        job = find_job('test_ng')
        executor = Executor.new(job, empty_args)
        assert executor.prepare
        assert executor.start
        job.process.wait
        assert job.process.failed?
        assert_equal 'ng', job.process.error.message
        assert_includes AbidTest.history, ['test_ng']
      end

      def test_start_before_prepare
        job = find_job('test_ok')
        executor = Executor.new(job, empty_args)
        refute executor.start
        assert executor.prepare
        assert executor.start
        job.process.wait
      end

      def test_cancel_in_prepare
        job = find_job('test_ok')
        mock_fail_state('test_ok')
        executor = Executor.new(job, empty_args)

        refute executor.prepare
        assert job.process.cancelled?

        refute executor.start
      end

      def test_skip_in_prepare
        job = find_job('test_ok')
        job.state.assume
        executor = Executor.new(job, empty_args)

        refute executor.prepare
        assert job.process.skipped?

        refute executor.start
      end

      def test_cancel_after_prerequsites
        job = find_job('test_p2', i: 0)
        job.prerequisites.each do |p|
          p.process.quit(RuntimeError.new('test'))
        end

        executor = Executor.new(job, empty_args)
        assert executor.prepare
        refute executor.start
        assert job.process.cancelled?
      end

      def test_prepare_after_running
        job = find_job('test_ok')
        executor = Executor.new(job, empty_args)
        job.process.prepare
        job.process.start
        refute executor.prepare
      end

      def test_start_twice
        job = find_job('test_ok')
        executor = Executor.new(job, empty_args)
        assert executor.prepare
        assert executor.start
        job.process.wait
        assert job.process.successed?

        executor2 = Executor.new(find_job('test_ok'), empty_args)
        refute executor2.prepare
        refute executor2.start
      end

      def test_execute_running
        job = find_job('test_ok')
        executor = Executor.new(job, empty_args)

        job.state.start
        executor.prepare
        executor.start
        job.process.wait
        assert job.process.failed?
        assert_kind_of AlreadyRunningError, job.process.error
      end
    end
  end
end
