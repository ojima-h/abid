module Abid
  class Task < Rake::Task
    extend Forwardable

    attr_accessor :play_class_definition
    attr_accessor :extends
    attr_accessor :play

    def_delegators :play, :params, :worker, :volatile?

    def initialize(task_name, app)
      super(task_name, app)
      @actions << proc { |t| t.play.invoke }
      @actions.freeze
    end

    def play_class
      return @play_class if @play_class

      klass = application.lookup_play_class(extends)
      @play_class = Class.new(klass, &play_class_definition).tap do |c|
        c.task = self
      end
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
