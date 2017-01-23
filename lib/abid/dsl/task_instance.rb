module Abid
  module DSL
    # Common interface for RakeTaskInstance and AbidTaskInstance
    class TaskInstance
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
      interface :params
      interface :worker
      interface :prerequisite_tasks
      interface :execute, %w(args)

      interface :volatile?
      interface :concerned?
      interface :needed?

      def initialize(task, params)
        @task = task
        @params = params
      end
      attr_reader :task, :params
      private :task, :params

      def trace_invoke
        return unless @task.application.options.trace
        @task.application.trace \
          "** Invoke #{@task.name} #{@task.format_trace_flags}"
      end
    end
  end
end
