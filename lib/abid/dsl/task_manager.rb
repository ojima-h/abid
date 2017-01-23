require 'monitor'

module Abid
  module DSL
    # TaskManager manages tasks.
    class TaskManager
      def initialize(application)
        @app = application
        @tasks = Hash.new { |h, k| h[k] = {} }
        @mon = Monitor.new
      end

      # Resolves params using params_spec and bind the task and resolved params.
      # @param name [String,Symbol] task name
      # @param params [Hash]
      # @param scope [Rake::Scope]
      # @return [Abid::DSL::TaskInstance]
      def [](name, params = {}, scope = nil)
        task = @app[name, scope]
        resolved = resolve_params(task, params)
        fetch(task.name, resolved)
      end

      # Binds the task and params.
      # @param name [String,Symbol] task name
      # @param params [Hash]
      # @return [Abid::DSL::TaskInstance]
      def bind(name, params)
        return @tasks[name][params] if @tasks[name][params]

        @mon.synchronize do
          @tasks[name][params.dup.freeze] ||= @app[name].bind(params)
        end
      end

      def resolve_params(task, params)
        params = @app.global_params.merge(params)

        task.params_spec.each_with_object({}) do |(key, spec), h|
          if params.include?(key)
            h[key] = params[key]
          elsif spec.include?(:default)
            h[key] = spec[:default]
          else
            raise "#{task.name}: param #{key} is not specified"
          end
        end
      end
    end
  end
end
