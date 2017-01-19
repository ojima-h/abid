require 'forwardable'
require 'abid/dsl/task_instance'

module Abid
  module DSL
    # Rake::Task wrapper.
    class RakeTaskInstance < TaskInstance
      extend Forwardable

      def_delegators :@task, :name, :execute, :arg_names

      def initialize(task, _params)
        @task = task
      end

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
        @task.needed?
      end

      def prerequisite_tasks
        @task.prerequisite_tasks.map { |preq| [preq, {}] }
      end

      def call_action(tag, *args); end
    end
  end
end
