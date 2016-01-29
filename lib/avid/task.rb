module Avid
  class Task < Rake::Task
    attr_accessor :play_class
    attr_accessor :play

    def initialize(task_name, app)
      super(task_name, app)
      @actions << proc { play.run }
      @actions.freeze
    end

    class <<self
      def define_play(*args, &block) # :nodoc:
        Rake.application.define_play(self, *args, &block)
      end
    end
  end
end
