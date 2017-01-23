module Abid
  class Engine
    class Job
      def initialize(engine, task)
        @engine = engine
        @task = task

        @process = Process.new(self)
        @state = find_state
        @options = engine.options
        @root = false
      end
      attr_reader :engine, :process, :state, :task, :options

      def find_state
        @engine.state_manager.state(task.name, task.params,
                                    dryrun: dryrun?, volatile: task.volatile?)
      end
      private :find_state

      def invoke(*args)
        Scheduler.invoke(self, *args)
        @process.wait
      end

      def root?
        @root
      end

      def root
        @root = true
        self
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

      # notified when process status is updated.
      def update_status
        @engine.job_manager.update(self)
      end
    end
  end
end
