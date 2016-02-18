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

      klass = application.lookup_play_class(extends, scope)
      @play_class = Class.new(klass, &play_class_definition).tap do |c|
        c.task = self
      end
    end

    def prerequisite_tasks
      fail 'no play is bound yet' if @play.nil?

      play.prerequisites.map do |pre, params|
        application[pre, @scope, **self.params.merge(params)]
      end
    end

    # Name of task with argument list description.
    def name_with_args # :nodoc:
      if params_description
        "#{super}#{params_description}"
      else
        super
      end
    end

    def params_description
      sig_params = play_class.params_spec.select do |_, spec|
        spec[:significant]
      end
      return if sig_params.empty?

      if play.nil? # unbound
        p = sig_params.map { |name, spec| "#{name}:#{spec[:type]}" }
      else
        p = sig_params.map { |name, _| "#{name}:#{play.params[name]}" }
      end

      "(#{p.join(' ')})"
    end

    class <<self
      def define_play(*args, &block) # :nodoc:
        Rake.application.define_play(self, *args, &block)
      end
    end
  end
end
