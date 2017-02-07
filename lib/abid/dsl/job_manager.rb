require 'monitor'

module Abid
  module DSL
    # JobManager manages jobs.
    class JobManager
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
        bind(task.name, resolved)
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
        ret = task.params_spec.each_with_object({}) do |(key, spec), h|
          h[key] = fetch_param(task, key, spec, params, @app.global_params)
        end
        ParamsFormat.validate_params!(ret)
        ret
      end

      def fetch_param(task, key, spec, *params_list)
        found = params_list.find { |params| params.include?(key) }
        return found[key] if found
        return spec[:default] if spec.include?(:default)
        raise "#{task.name}: param #{key} is not specified"
      end
      private :fetch_param

      # @param job [Job] collect prerequisites of the job.
      # @param target_job [Job] collect only prerequisites depending on
      #   `target_job` if specified.
      # @return [Array<Job>]
      def collect_prerequisites(job, target_job = nil)
        collect_prerequisites_iter(job, {}, target_job).keys
      end

      def collect_prerequisites_iter(job, checked, target_job = nil)
        return {} if checked.include?(job)
        checked[job] = nil

        return { job => nil } if target_job == job

        found = {}
        job.prerequisites.each do |preq|
          found.update(collect_prerequisites_iter(preq, checked, target_job))
        end
        found[job] = nil if target_job.nil? || !found.empty?
        found
      end
      private :collect_prerequisites_iter
    end
  end
end
