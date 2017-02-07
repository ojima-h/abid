require 'test_helper'

module Abid
  class Engine
    class WaiterTest < AbidTest
      def setup
        env.options.wait_external_task = true
        env.options.wait_external_task_interval = 0.1
        env.options.wait_external_task_timeout = 60
      end

      def test_wait
        job = find_job('test_ok')
        executor = Executor.new(job, empty_args)

        job.process.state_service.start

        executor.prepare
        executor.start

        job.process.wait(0.5)
        assert job.process.running?

        job.process.state_service.finish
        job.process.wait(0.5)

        assert job.process.successed?
      end

      def test_wait_fail
        job = find_job('test_ok')
        executor = Executor.new(job, empty_args)

        job.process.state_service.start

        executor.prepare
        executor.start

        job.process.wait(0.5)
        assert job.process.running?

        job.process.state_service.finish RuntimeError.new('test')
        job.process.wait(0.5)

        assert job.process.failed?
        assert_equal 'task failed while waiting', job.process.error.message
      end

      def test_revoked_while_waiting
        job = find_job('test_ok')
        executor = Executor.new(job, empty_args)

        job.process.state_service.start

        executor.prepare
        executor.start

        job.process.wait(0.5)
        assert job.process.running?

        env.state_manager.states[job.process.state_service.find.id].revoke(force: true)
        job.process.wait(0.5)

        assert job.process.failed?
        assert_equal 'unexpected task state', job.process.error.message
      end

      def test_timeout
        env.options.wait_external_task_timeout = 0.5

        job = find_job('test_ok')
        executor = Executor.new(job, empty_args)

        job.process.state_service.start

        executor.prepare
        executor.start

        job.process.wait(60)
        assert job.process.failed?
        assert_equal 'timeout', job.process.error.message
      end
    end
  end
end
