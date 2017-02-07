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
        process = find_process('test_ok')
        executor = Executor.new(process, empty_args)

        process.state_service.start

        executor.prepare
        executor.start

        process.wait(0.5)
        assert process.running?

        process.state_service.finish
        process.wait(0.5)

        assert process.successed?
      end

      def test_wait_fail
        process = find_process('test_ok')
        executor = Executor.new(process, empty_args)

        process.state_service.start

        executor.prepare
        executor.start

        process.wait(0.5)
        assert process.running?

        process.state_service.finish RuntimeError.new('test')
        process.wait(0.5)

        assert process.failed?
        assert_equal 'task failed while waiting', process.error.message
      end

      def test_revoked_while_waiting
        process = find_process('test_ok')
        executor = Executor.new(process, empty_args)

        process.state_service.start

        executor.prepare
        executor.start

        process.wait(0.5)
        assert process.running?

        env.state_manager.states[process.state_service.find.id].revoke(force: true)
        process.wait(0.5)

        assert process.failed?
        assert_equal 'unexpected task state', process.error.message
      end

      def test_timeout
        env.options.wait_external_task_timeout = 0.5

        process = find_process('test_ok')
        executor = Executor.new(process, empty_args)

        process.state_service.start

        executor.prepare
        executor.start

        process.wait(60)
        assert process.failed?
        assert_equal 'timeout', process.error.message
      end
    end
  end
end
