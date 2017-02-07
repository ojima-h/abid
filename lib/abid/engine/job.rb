module Abid
  class Engine
    class Job
      def initialize(engine, task)
        @engine = engine
        @task = task
        @state = find_state
        @options = engine.options
        @logger = @engine.logger.clone
        @logger.progname += ": #{@task}"

        @process = Process.new(self)
        @process.on_update { @engine.job_manager.update(self) }
      end
      attr_reader :engine, :process, :state, :task, :options, :logger

      def find_state
        @engine.state_manager.state(task.name, task.params,
                                    dryrun: dryrun?, volatile: task.volatile?)
      end
      private :find_state

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
