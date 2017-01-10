require 'test_helper'

module Abid
  module Engine
    class WaiterTest < AbidTest
      def setup
        env.options.wait_external_task = true
        env.options.wait_external_task_interval = 0.1
        env.options.wait_external_task_timeout = 60
      end

      def test_wait
        job = Job['test_ok']
        executor = Executor.new(job, empty_args)

        job.state.start

        executor.prepare
        executor.start

        job.process.wait(0.5)
        assert_equal :running, job.process.status

        job.state.finish
        job.process.wait(0.5)

        assert_equal :complete, job.process.status
        assert job.process.successed?
      end

      def test_wait_fail
        job = Job['test_ok']
        executor = Executor.new(job, empty_args)

        job.state.start

        executor.prepare
        executor.start

        job.process.wait(0.5)
        assert_equal :running, job.process.status

        job.state.finish RuntimeError.new('test')
        job.process.wait(0.5)

        assert_equal :complete, job.process.status
        assert job.process.failed?
        assert_equal 'task failed while waiting', job.process.error.message
      end

      def test_revoked_while_waiting
        job = Job['test_ok']
        executor = Executor.new(job, empty_args)

        job.state.start

        executor.prepare
        executor.start

        job.process.wait(0.5)
        assert_equal :running, job.process.status

        StateManager::State.revoke(job.state.id, force: true)
        job.process.wait(0.5)

        assert_equal :complete, job.process.status
        assert job.process.failed?
        assert_equal 'unexpected task state', job.process.error.message
      end

      def test_timeout
        env.options.wait_external_task_timeout = 0.5

        job = Job['test_ok']
        executor = Executor.new(job, empty_args)

        job.state.start

        executor.prepare
        executor.start

        job.process.wait(60)
        assert_equal :complete, job.process.status
        assert job.process.failed?
        assert_equal 'timeout', job.process.error.message
      end
    end
  end
end
