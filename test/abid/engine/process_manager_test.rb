require 'test_helper'

module Abid
  class Engine
    class ProcessManagerTest < AbidTest
      def test_acitves
        process = find_process('test_ok')
        process_manager = env.engine.process_manager

        process.prepare
        assert process_manager.active?(process)

        process.start
        assert process_manager.active?(process)

        process.finish
        refute process_manager.active?(process)
      end

      def test_summary
        mock_fail_state('test_p2', i: 1)
        invoke('test_p3')

        summary = @env.engine.summary
        assert_equal 3, summary[:successed]
        assert_equal 2, summary[:cancelled]
      end
    end
  end
end
