module Abid
  module TaskManager
    def initialize
      super
      @plays = {}
    end

    def define_play(task_class, play_name, extends: nil, &block)
      define_task(task_class, play_name).tap do |task|
        task.extends = extends
        task.play_class_definition = block
      end
    end

    def [](task_name, scopes = nil, **params)
      task = super(task_name, scopes)

      if task.respond_to? :play_class
        intern_play(task, **params)
      else
        task
      end
    end

    def intern_play(task, **params)
      play = task.play_class.new(**params)

      return @plays[play] if @plays.include?(play)

      play.setup
      @plays[play] = task.dup.tap { |t| t.play = play }
    end

    def play_base(&block)
      if block_given?
        @play_base = Class.new(Abid::Play, &block)
      else
        @play_base ||= Abid::Play
      end
    end

    def lookup_play_class(task_name, scope = nil)
      if task_name.nil?
        play_base
      else
        task_name = task_name.to_s
        t = lookup(task_name, scope)
        if t.respond_to? :play_class
          t.play_class
        elsif t.nil?
          fail "play #{task_name} not found"
        else
          fail "task #{task_name} has no play class"
        end
      end
    end

    class << self
      def record_task_metadata # :nodoc:
        Rake::TaskManager.record_task_metadata
      end
    end
  end
end
