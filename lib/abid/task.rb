module Abid
  class Task < Rake::Task
    extend Forwardable

    attr_accessor :play_class
    attr_accessor :play

    def_delegators :play, :params, :worker, :volatile?

    def initialize(task_name, app)
      super(task_name, app)
      @actions << proc { |t| t.play.invoke }
      @actions.freeze
    end

    def prerequisite_tasks
      fail 'no play is bound yet' if @play.nil?

      play.prerequisites.map do |pre, params|
        application[pre, @scope, **params]
      end
    end

    class <<self
      def define_play(*args, &block) # :nodoc:
        Rake.application.define_play(self, *args, &block)
      end
    end
  end
end
