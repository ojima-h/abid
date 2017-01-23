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
    end
  end
end
