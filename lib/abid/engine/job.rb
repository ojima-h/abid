module Abid
  class Engine
    class Job
      def initialize(engine, task)
        @engine = engine
        @task = task
        @options = engine.options

        @process = Process.new(self)
        @process.on_update { @engine.job_manager.update(self) }
      end
      attr_reader :engine, :process, :task, :options

      def root?
        @engine.job_manager.root?(self)
      end

      def prerequisites
        @task.prerequisite_tasks.map { |preq| @engine.jobs[preq] }
      end

      def worker
        @engine.worker_manager[task.worker]
      end

      def dryrun?
        @engine.options.dryrun || @engine.options.preview
      end

      def repair?
        @engine.options.repair
      end
    end
  end
end
