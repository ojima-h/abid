module Avid
  class Task < Rake::Task
    extend Forwardable

    attr_accessor :play_class
    attr_accessor :play

    def_delegators :play_class, :worker, :volatile?
    def_delegators :play, :params, :hash

    def initialize(task_name, app)
      super(task_name, app)
      @actions << proc { |t| t.play.run }
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
