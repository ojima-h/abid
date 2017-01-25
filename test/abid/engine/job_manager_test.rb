require 'test_helper'

module Abid
  class Engine
    class JobManagerTest < AbidTest
      def test_acitves
        job = find_job('test_ok')
        process = job.process
        job_manager = env.engine.job_manager

        process.prepare
        assert job_manager.active?(job)

        process.start
        assert job_manager.active?(job)

        process.finish
        refute job_manager.active?(job)
      end

      def test_summary
        mock_fail_state('test_p2', i: 1)
        job = find_job('test_p3')
        job.invoke

        summary = @env.engine.summary
        assert_equal 3, summary[:successed]
        assert_equal 2, summary[:cancelled]
      end
    end
  end
end
