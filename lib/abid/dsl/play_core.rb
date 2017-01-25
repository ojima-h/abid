module Abid
  module DSL
    # Common methods for Play and Mixin
    module PlayCore
      attr_reader :prerequisite_tasks
      attr_reader :params

      # Declared prerequisite tasks.
      #
      #     play :foo do
      #       setup do
      #         needs :TASK_NAME, bar: 0
      #       end
      #     end
      #
      # @param task_name [Symbol, String] task name
      # @param params [Hash] task params
      def needs(task_name, **params)
        t = task.application[task_name, @scope_in_actions]
        (@prerequisite_tasks ||= []) << [t, self.params.merge(params)]
      end

      def run
        # noop
      end

      def task
        self.class.task
      end

      # Evaluates each actions in the task scope where the action is declared.
      # @param tag [Symbol] action name
      # @param args [Array] arguments
      def call_action(tag, *args)
        self.class.actions[tag].each do |scope, block|
          @scope_in_actions = scope
          instance_exec(*args, &block)
        end
      ensure
        @scope_in_actions = nil
      end

      # @!visibility private
      def eval_setting(value = nil, &block)
        return instance_exec(&value) if value.is_a? Proc
        return value unless value.nil?
        return instance_exec(&block) if block_given?
        true
      end
      private :eval_setting

      def logger
        task.application.logger
      end

      def preview?
        task.application.options.dryrun || task.application.options.preview
      end

      # Play definition's body is extended by ClassMethods.
      #
      module ClassMethods
        attr_accessor :task
        private :task=

        # Task params specification.
        def params_spec
          @params_spec ||= ParamsSpec.new(self)
        end

        # Actions include `setup` blocks and `after` blocks.
        #
        #     play :foo do
        #       setup { 'this block is added to actions[:setup]' }
        #       after { ... }
        #     end
        def actions
          @actions ||= Actions.new(self)
        end

        # Define helper methods.
        #
        #     play :foo do
        #       helpers do
        #         def country
        #           :jp
        #         end
        #       end
        #
        #       today #=> :jp
        #     end
        #
        # `helpers` block is evaluated in the helpers module context, which
        # extends the play class.
        #
        # If no block given, it returns the helper module.
        #
        # @return [Module] helpers module
        def helpers(*extensions, &block)
          @helpers ||= Module.new
          @helpers.module_eval(&block) if block_given?
          @helpers.module_eval { include(*extensions) } if extensions.any?
          @helpers
        end

        # Declared setting.
        #
        #     play :foo do
        #       set :first_name, 'Taro'
        #       set :family_name, 'Yamada'
        #       set :full_name, -> { first_name + ' ' + family_name }
        #
        #       def run
        #         full_name #=> 'Taro Yamada'
        #       end
        #     end
        #
        # Settings are defiend as an intance methods of the play.
        #
        # If a param is declared with the same name of the setting, the param is
        # undefined.
        #
        #     mixin :bar do
        #       param :country
        #     end
        #
        #     play :baz do
        #       include :bar
        #       set :country, :jp
        #
        #       params_spec #=> {}
        #     end
        #
        # When block is given, it is lazily evaluated in the play context.
        def set(name, value = nil, &block)
          var = :"@#{name}"

          params_spec.delete(name) # undef param
          define_method(name) do
            unless instance_variable_defined?(var)
              val = eval_setting(value, &block)
              instance_variable_set(var, val)
            end
            instance_variable_get(var)
          end
        end

        # Declare task param.
        #
        #     play :foo do
        #       param :city
        #       param :country, default: 'Japan'
        #
        #       params_spec # => { city: {}, country: { default: 'Japan'} }
        #
        #       def run
        #         puts "#{city}, #{country}"
        #       end
        #     end
        #
        #     $ abid foo city=Tokyo
        #     Tokyo, Japan
        #
        # An instance method of the same name is defined.
        #
        # @param name [Symbol] param name
        # @param spec [Hash] specification
        # @option spec [Object] :default default value
        def param(name, **spec)
          define_method(name) do
            raise NoParamError, "undefined param `#{name}' for #{task.name}" \
              unless params.include?(name)
            params[name]
          end
          params_spec[name] = spec
        end

        #
        # Setting Helpers
        #

        # @!visibility private
        def self.def_setting_helper(name)
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{name}(val = nil, &block)
            set :#{name}, val, &block
          end
          RUBY
        end

        # @!method worker(val = nil, &block)
        #   Set :worker name.
        #
        #       play :foo do
        #         worker :my_worker
        #         action { ... }
        #       end
        #
        #   This is short-hand style of `set :worker, :my_worker`
        def_setting_helper :worker

        # @!method volatile(val = nil, &block)
        #   Set :volatile flag.
        #
        #       play :foo do
        #         volatile
        #         action { ... }
        #       end
        #
        #   This is short-hand style of `set :volatile, true`
        def_setting_helper :volatile

        # Delete the param from params_spec.
        #
        #     mixin :bar do
        #       param :country
        #     end
        #
        #     play :baz do
        #       include :bar
        #
        #       params_spec #=> { country: {} }
        #
        #       undef_param :country
        #       params_spec #=> {}
        #     end
        def undef_param(name)
          params_spec.delete(name)
        end

        #
        # Actions
        #

        # @!visibility :private
        def self.define_action(name)
          define_method(name) do |&block|
            actions.add(name, task.scope, block)
          end
        end

        # @!method setup(&block)
        #   Register _setup_ action.
        #
        #   Setup action is called before #run.
        #   All prerequisites should be declared inside the setup blocks.
        #
        #       play :foo do
        #         setup do
        #           needs :bar
        #           puts 'Setup!'
        #         end
        #
        #         def run
        #           puts 'Running!'
        #         end
        #       end
        #
        #       $ abid foo
        #       ... (:bar is executed)
        #       Setup!
        #       Running!
        define_action :setup

        # @!method action(&block)
        #   Register main action.
        #
        #       play :foo do
        #         action { |args| ... }
        #       end
        #
        #   `action` block is not executed in dryrun mode nor preview mode.
        #
        #   Main actions of mixis are inherited to play, while `run` method is
        #   overwritten.
        #
        #   @yieldparam args [Rake::TaskArguments]
        define_action :action

        # @!method safe_action(&block)
        #   Register safe action.
        #   `safe_action` is similar to `action`, but this block is executed
        #   in preview mode.
        #
        #   You should guard dangerous operations in a safe_action block.
        #   This is useful to preview detail behavior of play.
        #
        #   @yieldparam args [Rake::TaskArguments]
        define_action :safe_action

        # @!method after(&block)
        #   Register _after_ action.
        #
        #   After action is called after #run.
        #
        #       play :foo do
        #         def run
        #           ...
        #         end
        #
        #         after do |error|
        #           next if error.nil?
        #           $syserr.puts "[ERROR] #{task.name} failed:"
        #           $syserr.puts "[ERROR]   #{error}"
        #         end
        #       end
        #
        #   `after` block is not executed in dryrun mode nor preview mode.
        #
        #   @yieldparam error [StandardError, nil] if run method failed,
        #     otherwise nil.
        define_action :after

        # Include mixins.
        #
        # All methods, actions, settings and params_spec are inherited.
        #
        #     mixin :foo do
        #       param :country
        #     end
        #
        #     play :bar do
        #       include :bar
        #       params_spec #=> { country: {} }
        #     end
        #
        # When Module objects are given, it includes them as usual.
        #
        # @param mod [Array<Symbol, String, Module>] mixin name or module.
        def include(*mod)
          ms = mod.map { |m| resolve_mixin(m) }
          super(*ms)
        end
        private :include

        # @!visibility private
        def resolve_mixin(mod)
          return mod if mod.is_a? Module

          mixin_task = task.application[mod.to_s, task.scope]
          raise "#{mod} is not a mixin" unless mixin_task.is_a? MixinTask

          mixin_task.internal
        end
        private :resolve_mixin

        # Return a list of Mixin objects included.
        def superplays
          ancestors.select { |o| o.is_a? PlayCore::ClassMethods }
        end
      end
    end
  end
end
