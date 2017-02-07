require 'abid/dsl/job'

module Abid
  module DSL
    # Abid::DSL::Task wrapper
    class AbidJob < Job
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
        if dryrun?
          trace_execute
          return
        end
        play.call_action(:safe_action)
        play.call_action(:action, args) unless preview?
        run(args)
      ensure
        play.call_action(:after, $ERROR_INFO) unless dryrun? || preview?
      end

      def run(args)
        if play.method(:run).arity.zero?
          play.run
        else
          play.run(args)
        end
      end

      def prerequisites
        ps = task.prerequisite_tasks.map { |preq| [preq, params] } \
           + play.prerequisite_tasks

        ps.map do |preq, params|
          task.application.job_manager[preq.name, params]
        end
      end

      def volatile?
        play.volatile || task.application.options.disable_state
      end

      def trace_execute
        task.application.trace "** Execute (dry run) #{task.name}"
      end
      private :trace_execute
    end
  end
end
