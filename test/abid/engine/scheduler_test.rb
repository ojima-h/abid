require 'test_helper'

module Abid
  module Engine
    class SchedulerTest < AbidTest
      def test_invoke_ok
        job = Job['test_ok']
        Engine.invoke(job)
        assert job.state.successed?
        assert job.process.successed?
        assert_equal :complete, job.process.status
        assert_includes AbidTest.history, ['test_ok']
      end

      def test_invoke_ng
        job = Job['test_ng']
        Engine.invoke(job)
        assert job.state.failed?
        assert job.process.failed?
        assert_equal :complete, job.process.status
        assert_equal 'ng', job.process.error.message
        assert_includes AbidTest.history, ['test_ng']
      end

      def test_invoke
        job = Job['test_p3']
        Engine.invoke(job)

        assert job.state.successed?
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
        job_failed = Job['test_p2', i: 1]
        job_failed.state.mock_fail RuntimeError.new('test')

        job = Job['test_p3']
        Engine.invoke(job)

        assert job.state.new?
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
        job = Job['test_p2', i: 1]
        job.state.mock_fail RuntimeError.new('test')

        job.task.stub(:top_level?, true) do
          Engine.invoke(job)
        end

        assert job.state.successed?
        assert job.process.successed?

        assert_equal 2, AbidTest.history.length
        assert_includes AbidTest.history, ['test_p1', i: 1]
        assert_includes AbidTest.history, ['test_p2', i: 1]
      end

      def test_invoke_already_successed
        job_successed = Job['test_p2', i: 1]
        job_successed.state.assume

        job = Job['test_p3']
        Engine.invoke(job)

        assert job.state.successed?
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
        in_repair_mode do
          job_successed = Job['test_p1', i: 0]
          job_successed.state.assume

          job_failed = Job['test_p1', i: 1]
          job_failed.state.mock_fail RuntimeError.new('test')

          job = Job['test_p3']
          Engine.invoke(job)

          assert job.state.successed?
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
        assert_raises RuntimeError, /Circular dependency/ do
          Engine.invoke(Job['scheduler_test:c1'])
        end
      end

      def test_with_args
        Engine.invoke(Job['test_args:t1'], 'Tom', '24')
        assert_includes AbidTest.history, ['test_args:t1', name: 'Tom', age: '24']
        assert_includes AbidTest.history, ['test_args:t2', age: '24']
      end
    end
  end
end
