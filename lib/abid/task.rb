module Abid
  class Task < Rake::Task
    extend Forwardable

    attr_accessor :play_class_definition, :extends
    attr_reader :play, :params

    def_delegators :play, :worker, :volatile?

    def initialize(task_name, app)
      super(task_name, app)
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
          call_play_hooks(:setup)
          bind_play_hooks(:before, :before_execute)
          bind_play_hooks(:after, :after_invoke)
        end
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

    # Name of task with params
    def name_with_params # :nodoc:
      if params_description
        "#{name} #{params_description}"
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

    # Execute the play associated with this task.
    def execute(_args = nil)
      fail 'no play is bound yet' unless bound?

      if application.options.dryrun
        application.trace "** Execute (dry run) #{name_with_params}"
        return
      end
      if application.options.trace
        application.trace "** Execute #{name_with_params}"
      end

      play.run
    end

    def concerned?
      state.reload

      if !application.options.repair && state.failed? && !top_level?
        fail "#{name} -- task has been failed"
      end

      application.options.repair || !state.successed?
    end

    def needed?
      !state.successed? || prerequisite_tasks.any? { |t| t.session.updated? }
    end

    def bind_play_hooks(tag, to = nil)
      to ||= tag
      hooks[to] = [proc { |*args| call_play_hooks(tag, *args) }]
    end

    def call_play_hooks(tag, *args)
      return unless bound?
      play_class.hooks[tag].each { |blk| play.instance_exec(*args, &blk) }
    end

    class <<self
      def define_play(*args, &block) # :nodoc:
        Rake.application.define_play(self, *args, &block)
      end
    end
  end
end
