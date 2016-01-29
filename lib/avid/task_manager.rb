module Avid
  module TaskManager
    def initialize
      super
      @plays = {}
    end

    def define_play(task_class, play_name, extends: nil, &block)
      task = define_task(task_class, play_name)

      klass = lookup_play_class(extends)
      task.play_class = Class.new(klass, &block).tap { |c| c.task = task }

      task
    end

    def [](task_name, scopes = nil, **params)
      task = super(task_name, scopes)

      if task.is_a?(Avid::Task)
        intern_play(task, **params)
      else
        task
      end
    end

    def intern_play(task, **params)
      play = task.play_class.new(**params)

      @plays[play] ||= task.dup.tap do |t|
        play.setup
        t.play = play
      end
    end

    def default_play_class(&block)
      if block_given?
        @default_play_class = Class.new(Avid::Play, &block)
      else
        @default_play_class ||= Avid::Play
      end
    end

    def lookup_play_class(task_name, scope = nil)
      if task_name.nil?
        default_play_class
      else
        task_name = task_name.to_s
        t = lookup(task_name, scope)
        if t.is_a? Avid::Task
          t.play_class
        else
          fail 'task must be an Avid::Task'
        end
      end
    end
  end
end
