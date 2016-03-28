module Abid
  module RakeExtensions
    module Task
      def volatile?
        true
      end

      def worker
        :default
      end

      def session
        @session ||= Session.new(self).tap do |session|
          session.add_observer do |_, _, reason|
            call_hooks(:after_invoke, reason)
          end
        end
      end

      def state
        State.find(self)
      end

      def name_with_params
        name
      end

      def concerned?
        true
      end

      def top_level?
        application.top_level_tasks.any? { |t| application[t] == self }
      end

      def hooks
        @hooks ||= Hash.new { |h, k| h[k] = [] }
      end

      def call_hooks(tag, *args)
        hooks[tag].each { |h| h.call(*args) }
      end

      def async_invoke(*args)
        task_args = Rake::TaskArguments.new(arg_names, args)
        async_invoke_with_call_chain(task_args, Rake::InvocationChain::EMPTY)
      end

      def async_invoke_with_call_chain(task_args, invocation_chain)
        session.enter do
          new_chain = Rake::InvocationChain.append(self, invocation_chain)

          unless concerned?
            session.skip
            break
          end

          call_hooks(:before_invoke)

          async_invoke_prerequisites(task_args, new_chain)

          async_execute_after_prerequisites(task_args)
        end
      end

      def async_invoke_prerequisites(task_args, invocation_chain)
        prerequisite_tasks.each do |t|
          args = task_args.new_scope(t.arg_names)
          t.async_invoke_with_call_chain(args, invocation_chain)
        end
      end

      def async_execute_after_prerequisites(task_args)
        if prerequisite_tasks.empty?
          async_execute(task_args)
        else
          counter = Concurrent::DependencyCounter.new(prerequisite_tasks.size) do
            session.capture_exception do
              async_execute(task_args)
            end
          end
          prerequisite_tasks.each { |t| t.session.add_observer counter }
        end
      end

      def async_execute(task_args)
        failed_task = prerequisite_tasks.find { |t| t.session.failed? }
        if failed_task
          session.fail(failed_task.session.error)
          return
        end

        application.worker[worker].post do
          session.capture_exception do
            if !needed?
              session.skip
            elsif session.lock
              call_hooks(:before_execute)

              execute(task_args)

              session.success
            else
              async_wait_external
            end
          end
        end
      end

      def async_wait_external
        unless application.options.wait_external_task
          fail "task #{name_with_params} already running"
        end

        application.trace "** Wait #{name_with_params}" if application.options.trace

        application.worker[:waiter].post do
          session.capture_exception do
            interval = application.options.wait_external_task_interval || 10
            timeout = application.options.wait_external_task_timeout || 3600
            timeout_tm = Time.now.to_f + timeout

            loop do
              state.reload
              if !state.running?
                session.success
                break
              elsif Time.now.to_f >= timeout_tm
                fail "#{name} -- timeout exceeded"
              else
                sleep interval
              end
            end
          end
        end
      end
    end
  end
end
