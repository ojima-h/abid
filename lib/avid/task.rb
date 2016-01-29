module Avid
  class Task < Rake::Task
    attr_reader :play_class
    attr_accessor :play

    def ==(other)
      if !play.nil? && other.is_a?(Avid::Task)
        play.hash == other.play.hash
      else
        super(other)
      end
    end

    def initialize_copy(_obj)
      @already_invoked = false
      @lock            = Monitor.new
    end

    def define_play_class(base_task = nil, &block)
      klass = application.lookup_play_class(base_task, scope)
      @play_class = Class.new(klass, &block)
    end

    def bind(**params)
      dup.tap { |t| t.play = play_class.new(**params) }
    end

    def execute
    end

    class <<self
      def define_play(play_name, extends: nil, &block) # :nodoc:
        task = Rake.application.define_task(self, play_name)
        task.define_play_class(extends, &block)
        task
      end
    end
  end
end
