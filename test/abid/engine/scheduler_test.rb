require 'test_helper'

module Abid
  class Engine
    class SchedulerTest < AbidTest
      def test_invoke_ok
        job = find_job('test_ok')
        job.invoke
        assert job.state.find.successed?
        assert job.process.successed?
        assert_equal :complete, job.process.status
        assert_includes AbidTest.history, ['test_ok']
      end

      def test_invoke_ng
        job = find_job('test_ng')
        job.invoke
        assert job.state.find.failed?
        assert job.process.failed?
        assert_equal :complete, job.process.status
        assert_equal 'ng', job.process.error.message
        assert_includes AbidTest.history, ['test_ng']
      end

      def test_invoke
        job = find_job('test_p3')
        job.invoke

        assert job.state.find.successed?
        assert job.process.successed?

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
        job_failed = find_job('test_p2', i: 1)
        mock_fail_state('test_p2', i: 1)

        job = find_job('test_p3')
        job.invoke

        assert job.state.find.new?
        assert job.process.cancelled?
        assert 'task has been failed', job_failed.process.error.message

        assert_includes AbidTest.history, ['test_p1', i: 0]
        refute_includes AbidTest.history, ['test_p1', i: 1]
        assert_includes AbidTest.history, ['test_p2', i: 0]
        refute_includes AbidTest.history, ['test_p2', i: 1]
        assert_includes AbidTest.history, ['test_t1']
        refute_includes AbidTest.history, ['test_p3']
      end

      def test_invoke_already_failed_directly
        job = find_job('test_p2', i: 1).root
        mock_fail_state('test_p2', i: 1)
        job.invoke

        assert job.state.find.successed?
        assert job.process.successed?

        assert_equal 2, AbidTest.history.length
        assert_includes AbidTest.history, ['test_p1', i: 1]
        assert_includes AbidTest.history, ['test_p2', i: 1]
      end

      def test_invoke_already_successed
        job_successed = find_job('test_p2', i: 1)
        job_successed.state.assume

        job = find_job('test_p3')
        job.invoke

        assert job.state.find.successed?
        assert job.process.successed?
        assert job_successed.process.skipped?

        assert_includes AbidTest.history, ['test_p1', i: 0]
        refute_includes AbidTest.history, ['test_p1', i: 1]
        assert_includes AbidTest.history, ['test_p2', i: 0]
        refute_includes AbidTest.history, ['test_p2', i: 1]
        assert_includes AbidTest.history, ['test_t1']
        assert_includes AbidTest.history, ['test_p3']
      end

      def test_invoke_in_repair_mode
        in_options(repair: true) do
          job_successed = find_job('test_p1', i: 0)
          job_successed.state.assume

          job_failed = find_job('test_p1', i: 1)
          mock_fail_state('test_p1', i: 1)

          job = find_job('test_p3')
          job.invoke

          assert job.state.find.successed?
          assert job.process.successed?
          assert job_successed.process.skipped?
          assert job_failed.process.successed?

          refute_includes AbidTest.history, ['test_p1', i: 0]
          assert_includes AbidTest.history, ['test_p1', i: 1]
          refute_includes AbidTest.history, ['test_p2', i: 0]
          assert_includes AbidTest.history, ['test_p2', i: 1]
          assert_includes AbidTest.history, ['test_t1']
          assert_includes AbidTest.history, ['test_p3']
        end
      end

      def test_circular_dependency
        err = assert_raises RuntimeError do
          find_job('scheduler_test:c1').invoke
        end
        assert_match(/Circular dependency/, err.message)
      end

      def test_with_args
        find_job('test_args:t1').invoke('Tom', '24')
        assert_includes AbidTest.history, ['test_args:t1', name: 'Tom', age: '24']
        assert_includes AbidTest.history, ['test_args:t2', age: '24']
      end
    end
  end
end
