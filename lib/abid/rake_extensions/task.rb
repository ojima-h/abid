module Abid
  module RakeExtensions
    module Task
      def volatile?
        true
      end

      def worker
        :default
      end

      def state
        @state ||= State.find(self)
      end

      def invoke(*args)
        async_invoke(*args).wait!
      end

      def async_invoke(*args)
        task_args = Rake::TaskArguments.new(arg_names, args)
        async_invoke_with_call_chain(task_args, Rake::InvocationChain::EMPTY)
      end

      def async_invoke_with_call_chain(task_args, invocation_chain)
        state.reload
        new_chain = Rake::InvocationChain.append(self, invocation_chain)
        @lock.synchronize do
          if application.futures.include?(object_id)
            return application.futures[object_id]
          end

          application.trace "** Invoke #{name}" if application.options.trace

          preq_futures = async_invoke_prerequisites(task_args, new_chain)

          future = async_invoke_after_prerequisites(task_args, preq_futures)

          application.futures[object_id] = future
        end
      end

      def async_invoke_prerequisites(task_args, invocation_chain)
        # skip if successed
        if state.successed?
          if !application.options.check_prerequisites
            preqs = []
          else
            preqs = prerequisite_tasks.reject(&:volatile?)
          end
        else
          preqs = prerequisite_tasks
        end

        preqs.map do |p|
          preq_args = task_args.new_scope(p.arg_names)
          p.async_invoke_with_call_chain(preq_args, invocation_chain)
        end
      end

      def async_invoke_after_prerequisites(task_args, preq_futures)
        if preq_futures.empty?
          async_execute_with_session(task_args, false)
        else
          result = Concurrent::IVar.new
          counter = Concurrent::DependencyCounter.new(preq_futures.size) do
            begin
              failed_preq = preq_futures.find(&:rejected?)
              next result.fail(failed_preq.reason) if failed_preq

              preq_updated = preq_futures.map(&:value!).any?

              future = async_execute_with_session(task_args, preq_updated)

              future.add_observer do |_time, value, reason|
                reason.nil? ? result.set(value) : result.fail(reason)
              end
            rescue Exception => err
              result.fail(err)
            end
          end
          preq_futures.each { |p| p.add_observer counter }
          result
        end
      end

      def async_execute_with_session(task_args, prerequisites_updated = false)
        if (state.successed? && !prerequisites_updated) || !needed?
          application.trace "** Skip #{name}" if application.options.trace
          return Concurrent::IVar.new(false)
        end

        session_started = state.start_session

        return async_wait_complete unless session_started

        pool = application.worker[worker]
        future = Concurrent::Future.execute(executor: pool) do
          begin
            execute(task_args)
            true
          ensure
            state.close_session($ERROR_INFO)
          end
        end
      ensure
        # close session if error occurred outside the future
        if session_started && future.nil? && $ERROR_INFO
          state.close_session($ERROR_INFO)
        end
      end

      def async_wait_complete
        unless application.options.wait_external_task
          err = RuntimeError.new("task #{name} already running")
          return Concurrent::IVar.new.fail(err)
        end

        application.trace "** Wait #{name}" if application.options.trace

        pool = application.worker[:waiter]
        Concurrent::Future.execute(executor: pool) do
          interval = application.options.wait_external_task_interval || 10
          timeout = application.options.wait_external_task_timeout || 3600
          timeout_tm = Time.now.to_f + timeout

          loop do
            state.reload
            break unless state.running?

            sleep interval
            break if Time.now.to_f >= timeout_tm
          end
          true
        end
      end
    end
  end
end
