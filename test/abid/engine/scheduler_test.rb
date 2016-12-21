require 'test_helper'

module Abid
  module Engine
    class SchedulerTest < AbidTest
      def test_invoke_ok
        job = Job['test_ok']
        Scheduler.invoke(job)
        assert job.state.successed?
        assert_equal :successed, job.process.result
      end

      def test_invoke_ng
        job = Job['test_ng']
        Scheduler.invoke(job)
        assert job.state.failed?
        assert_equal :failed, job.process.result
      end

      def test_invoke
        job = Job['test_p3']
        Scheduler.invoke(job)

        assert_equal :successed, job.process.result
        assert job.state.successed?

        assert_includes AbidTest.history, ['test_p1', i: 0]
        assert_includes AbidTest.history, ['test_p1', i: 1]
        assert_includes AbidTest.history, ['test_p2', i: 0]
        assert_includes AbidTest.history, ['test_p2', i: 1]
        assert_includes AbidTest.history, ['test_t1']
        assert_includes AbidTest.history, ['test_p3']

        ip1 = AbidTest.history.index(['test_p1', i: 0])
        ip2 = AbidTest.history.index(['test_p2', i: 0])
        it1 = AbidTest.history.index(['test_t1'])
        ip3 = AbidTest.history.index(['test_p3'])
        assert ip1 < ip2, 'p1 invoked before p2'
        assert ip2 < ip3, 'p2 invoked before p3'
        assert it1 < ip3, 't1 invoked before p3'
      end

      def test_invoke_already_failed
        job_failed = Job['test_p2', i: 1]
        job_failed.mock_fail RuntimeError.new('test')

        job = Job['test_p3']
        Scheduler.invoke(job)

        assert_equal :cancelled, job.process.result
        assert job.state.new?
        assert 'task has been failed', job_failed.process.error.message

        assert_includes AbidTest.history, ['test_p1', i: 0]
        refute_includes AbidTest.history, ['test_p1', i: 1]
        assert_includes AbidTest.history, ['test_p2', i: 0]
        refute_includes AbidTest.history, ['test_p2', i: 1]
        assert_includes AbidTest.history, ['test_t1']
        refute_includes AbidTest.history, ['test_p3']
      end

      def test_invoke_already_failed_directly
        job = Job['test_p2', i: 1]
        job.mock_fail RuntimeError.new('test')

        Scheduler.invoke(job)

        assert_equal :successed, job.process.result
        assert job.state.successed?

        assert_equal 2, AbidTest.history.length
        assert_includes AbidTest.history, ['test_p1', i: 1]
        assert_includes AbidTest.history, ['test_p2', i: 1]
      end

      def test_invoke_already_successed
        job_successed = Job['test_p2', i: 1]
        job_successed.assume

        job = Job['test_p3']
        Scheduler.invoke(job)

        assert_equal :successed, job.process.result
        assert job.state.successed?
        assert_equal :skipped, job_successed.process.result

        assert_includes AbidTest.history, ['test_p1', i: 0]
        refute_includes AbidTest.history, ['test_p1', i: 1]
        assert_includes AbidTest.history, ['test_p2', i: 0]
        refute_includes AbidTest.history, ['test_p2', i: 1]
        assert_includes AbidTest.history, ['test_t1']
        assert_includes AbidTest.history, ['test_p3']
      end

      def test_invoke_in_repair_mode
        in_repair_mode do
          job_successed = Job['test_p1', i: 0]
          job_successed.assume

          job_failed = Job['test_p1', i: 1]
          job_failed.mock_fail RuntimeError.new('test')

          job = Job['test_p3']
          Scheduler.invoke(job)

          assert_equal :successed, job.process.result
          assert job.state.successed?
          assert_equal :skipped, job_successed.process.result
          assert_equal :successed, job_failed.process.result

          refute_includes AbidTest.history, ['test_p1', i: 0]
          assert_includes AbidTest.history, ['test_p1', i: 1]
          refute_includes AbidTest.history, ['test_p2', i: 0]
          assert_includes AbidTest.history, ['test_p2', i: 1]
          assert_includes AbidTest.history, ['test_t1']
          assert_includes AbidTest.history, ['test_p3']
        end
      end

      def test_circular_dependency
        c1 = Job['scheduler_test:c1']
        c3 = Job['scheduler_test:c3']

        Scheduler.invoke(c1)

        assert_equal :cancelled, c1.process.result
        assert_equal :failed, c3.process.result
        assert_match(/Circular dependency/, c3.process.error.message)
      end
    end
  end
end
