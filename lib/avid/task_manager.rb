module Avid
  module TaskManager
    def [](task_name, scopes = nil, **params)
      task = super(task_name, scopes)

      if task.is_a?(Avid::Task)
        task.bind(**params)
      else
        task
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
