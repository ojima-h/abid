module Abid
  class Task < Rake::Task
    extend Forwardable

    attr_accessor :play_class_definition, :extends
    attr_reader :play, :params

    def_delegators :play, :worker, :volatile?

    def initialize(task_name, app)
      super(task_name, app)
      @actions << proc { |t| t.execute_play }
      @actions.freeze
      @siblings = {}
    end

    def play_class
      return @play_class if @play_class

      klass = application.lookup_play_class(extends, scope)
      @play_class = Class.new(klass, &play_class_definition).tap do |c|
        c.task = self
      end
    end

    def bound?
      !@play.nil?
    end

    def bind(**params)
      fail 'already bound' if bound?

      parsed_params = ParamsParser.parse(params, play_class.params_spec)
      return @siblings[parsed_params] if @siblings.include?(parsed_params)

      sorted_params = parsed_params.sort.to_h
      sorted_params.freeze

      @siblings[sorted_params] = dup.tap do |t|
        t.instance_eval do
          @prerequisites = []
          @params = sorted_params
          @play = play_class.new(t)
        end
        play_class.hooks[:setup].each { |blk| t.play.instance_eval(&blk) }
      end
    end

    def prerequisite_tasks
      fail 'no play is bound yet' unless bound?

      prerequisites.map do |pre, params|
        application[pre, @scope, **self.params.merge(params)]
      end
    end

    # Name of task with argument list description.
    def name_with_args # :nodoc:
      if params_description
        "#{super} #{params_description}"
      else
        super
      end
    end

    def params_description
      sig_params = play_class.params_spec.select do |_, spec|
        spec[:significant]
      end
      return if sig_params.empty?

      if bound? # unbound
        p = sig_params.map { |name, _| "#{name}=#{params[name]}" }
      else
        p = sig_params.map { |name, spec| "#{name}:#{spec[:type]}" }
      end

      p.join(' ')
    end

    def execute_play
      play_class.hooks[:before].each { |blk| play.instance_eval(&blk) }

      call_around_hooks(play_class.hooks[:around]) { play.run }

      play_class.hooks[:after].each { |blk| play.instance_eval(&blk) }
    end

    def call_around_hooks(hooks, &body)
      if hooks.empty?
        body.call
      else
        h, *rest = hooks
        play.instance_exec(-> { call_around_hooks(rest, &body) }, &h)
      end
    end
    private :call_around_hooks

    class <<self
      def define_play(*args, &block) # :nodoc:
        Rake.application.define_play(self, *args, &block)
      end
    end
  end
end
