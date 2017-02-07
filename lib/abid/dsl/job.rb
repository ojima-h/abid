require 'forwardable'

module Abid
  module DSL
    # Common interface for RakeJob and AbidJob
    class Job
      extend Forwardable

      def self.interface(name, args = [])
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}(#{args.join(', ')})
          raise NotImplementedError
        end
        RUBY
      end
      private_class_method :interface

      interface :name
      interface :arg_names
      interface :worker
      interface :prerequisites
      interface :execute, %w(args)

      interface :volatile?
      interface :concerned?
      interface :needed?

      def initialize(task, params)
        @task = task
        @params = params
        @options = task.application.options
      end
      attr_reader :task, :params, :options
      def_delegators :task, :name, :arg_names

      def trace_invoke
        return unless @task.application.options.trace
        @task.application.trace "** Invoke #{@task.name}"
      end

      def to_s
        ParamsFormat.format_with_name(name, params)
      end

      def repair?
        @options.repair
      end

      def dryrun?
        @options.dryrun
      end

      def preview?
        @options.preview
      end
    end
  end
end
