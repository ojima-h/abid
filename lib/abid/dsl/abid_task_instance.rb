require 'abid/dsl/task_instance'

module Abid
  module DSL
    # Abid::DSL::Task wrapper
    class AbidTaskInstance < TaskInstance
      def_delegators :play, :worker
      def_delegator :play, :concerned, :concerned?
      def_delegator :play, :needed,    :needed?

      def initialize(task, params)
        super
        @play = task.internal.new(params)
        @play.call_action(:setup)
      end
      attr_reader :play
      private :play

      def execute(args)
        if task.application.options.dryrun
          task.application.trace "** Execute (dry run) #{task.name}"
          return
        end
        run(args)
      end

      def run(args)
        play.call_action(:action, args)

        if play.method(:run).arity.zero?
          play.run
        else
          play.run(args)
        end
      ensure
        play.call_action(:after, $ERROR_INFO)
      end

      def prerequisite_tasks
        ps = task.prerequisite_tasks.map { |preq| [preq, params] } \
           + play.prerequisite_tasks

        ps.map do |preq, params|
          task.application.abid_tasks[preq.name, params]
        end
      end

      def volatile?
        play.volatile || task.application.options.disable_state
      end
    end
  end
end
