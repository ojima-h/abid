module Abid
  module TaskManager
    def initialize
      super
    end

    def define_play(task_class, play_name, extends: nil, &block)
      define_task(task_class, play_name).tap do |task|
        task.extends = extends
        task.play_class_definition = block
      end
    end

    def define_mixin(task_class, mixin_name, &block)
      define_task(task_class, mixin_name).tap do |task|
        task.mixin_definition = block
      end
    end

    def [](task_name, scopes = nil, **params)
      task = super(task_name, scopes)

      if task.respond_to? :bind
        task.bind(**params)
      else
        task
      end
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
      elsif task_name.is_a? Class
        task_name
      else
        t = lookup(task_name.to_s, scope)
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
