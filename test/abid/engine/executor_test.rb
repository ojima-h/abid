require 'test_helper'

module Abid
  class Engine
    class ExecutorTest < AbidTest
      def test_execute_ok
        process = find_process('test_ok')
        executor = Executor.new(process, empty_args)
        assert executor.prepare
        assert executor.start
        process.wait
        assert process.successed?
        assert_includes AbidTest.history, ['test_ok']
      end

      def test_execute_ng
        process = find_process('test_ng')
        executor = Executor.new(process, empty_args)
        assert executor.prepare
        assert executor.start
        process.wait
        assert process.failed?
        assert_equal 'ng', process.error.message
        assert_includes AbidTest.history, ['test_ng']
      end

      def test_start_before_prepare
        process = find_process('test_ok')
        executor = Executor.new(process, empty_args)
        refute executor.start
        assert executor.prepare
        assert executor.start
        process.wait
      end

      def test_cancel_in_prepare
        process = find_process('test_ok')
        mock_fail_state('test_ok')
        executor = Executor.new(process, empty_args)

        refute executor.prepare
        assert process.cancelled?

        refute executor.start
      end

      def test_skip_in_prepare
        process = find_process('test_ok')
        process.state_service.assume
        executor = Executor.new(process, empty_args)

        refute executor.prepare
        assert process.skipped?

        refute executor.start
      end

      def test_cancel_after_prerequsites
        process = find_process('test_p2', i: 0)
        process.prerequisites.each do |preq|
          preq.quit(RuntimeError.new('test'))
        end

        executor = Executor.new(process, empty_args)
        assert executor.prepare
        refute executor.start
        assert process.cancelled?
      end

      def test_prepare_after_running
        process = find_process('test_ok')
        executor = Executor.new(process, empty_args)
        process.prepare
        process.start
        refute executor.prepare
      end

      def test_start_twice
        process = find_process('test_ok')
        executor = Executor.new(process, empty_args)
        assert executor.prepare
        assert executor.start
        process.wait
        assert process.successed?

        executor2 = Executor.new(find_process('test_ok'), empty_args)
        refute executor2.prepare
        refute executor2.start
      end

      def test_execute_running
        process = find_process('test_ok')
        executor = Executor.new(process, empty_args)

        process.state_service.start
        executor.prepare
        executor.start
        process.wait
        assert process.failed?
        assert_kind_of AlreadyRunningError, process.error
      end

      def test_force_mode
        find_process('test_p3').state_service.assume
        mock_fail_state('test_p2', i: 0)

        in_options(force: true) do
          process = invoke('test_p3')

          assert process.state_service.find.successed?
          assert process.successed?

          assert_includes AbidTest.history, ['test_p3']
          refute_includes AbidTest.history, ['test_p2', i: 0]
          refute_includes AbidTest.history, ['test_p2', i: 1]
        end
      end
    end
  end
end
