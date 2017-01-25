require 'abid/dsl/task_instance'

module Abid
  module DSL
    # Rake::Task wrapper.
    class RakeTaskInstance < TaskInstance
      def volatile?
        true
      end

      def worker
        :default
      end

      def params
        {}
      end

      def concerned?
        true
      end

      def needed?
        task.needed?
      end

      def execute(args)
        task.application.trace "** Execute (dry run) #{task.name}" if dryrun?
        return if dryrun? || preview?

        task.execute(args)
      end

      def prerequisite_tasks
        task.prerequisite_tasks.map do |preq|
          task.application.abid_tasks.bind(preq.name, {})
        end
      end
    end
  end
end
