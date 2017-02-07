require 'test_helper'

module Abid
  module DSL
    class JobManagerTest < AbidTest
      def job_manager
        @env.application.job_manager
      end

      def test_collect_prerequisites
        job = job_manager['test_p3']
        target_job = job_manager['test_p1', i: 1]

        found = job_manager.collect_prerequisites(job, target_job)
        assert_equal [
          job_manager['test_p1', i: 1],
          job_manager['test_p2', i: 1],
          job_manager['test_p3']
        ], found
      end

      def test_collect_prerequisites_all
        job = job_manager['test_p3']

        found = job_manager.collect_prerequisites(job)
        assert_equal [
          job_manager['test_p1', i: 0],
          job_manager['test_p2', i: 0],
          job_manager['test_p1', i: 1],
          job_manager['test_p2', i: 1],
          job_manager['test_t1'],
          job_manager['test_p3']
        ], found
      end
    end
  end
end
