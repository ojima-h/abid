require 'forwardable'
require 'abid/dsl/task_instance'

module Abid
  module DSL
    # Abid::DSL::Task wrapper
    class AbidTaskInstance < TaskInstance
      extend Forwardable

      def_delegators :@task, :name, :arg_names
      def_delegators :@play, :params, :worker
      def_delegator :@play, :volatile,  :volatile?
      def_delegator :@play, :concerned, :concerned?
      def_delegator :@play, :needed,    :needed?

      def initialize(task, params)
        @task = task
        @play = @task.internal.new(params)
        @play.call_action(:setup)
      end

      def execute(args)
        run(args)
      ensure
        @play.call_action(:after, $ERROR_INFO)
      end

      def run(args)
        if @play.method(:run).arity.zero?
          @play.run
        else
          @play.run(args)
        end
      end

      def prerequisite_tasks
        @task.prerequisite_tasks.map { |preq| [preq, params] } \
          + @play.prerequisite_tasks
      end
    end
  end
end
