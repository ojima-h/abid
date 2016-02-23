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
        State.find(self)
      end

      def name_with_params
        name
      end

      def async_invoke(*args)
        task_args = Rake::TaskArguments.new(arg_names, args)
        async_invoke_with_call_chain(task_args, Rake::InvocationChain::EMPTY)
      end

      def async_invoke_with_call_chain(task_args, invocation_chain)
        state.reload

        new_chain = Rake::InvocationChain.append(self, invocation_chain)

        state.only_once do
          application.trace "** Invoke #{name_with_params}" if application.options.trace

          preq_futures = async_invoke_prerequisites(task_args, new_chain)

          async_invoke_after_prerequisites(task_args, preq_futures)
        end
        state.ivar
      ensure
        state.ivar.try_fail($ERROR_INFO) if $ERROR_INFO
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
          counter = Concurrent::DependencyCounter.new(preq_futures.size) do
            preq_values = preq_futures.map(&:value)
            preq_failed = preq_futures.select(&:rejected?)
            if preq_failed.empty?
              async_execute_with_session(task_args, preq_values.any?)
            else
              err = "#{preq_failed.length} parent tasks failed"
              state.ivar.try_fail(StandardError.new(err))
            end
          end
          preq_futures.each { |p| p.add_observer counter }
        end
      end

      def async_execute_with_session(task_args, prerequisites_updated = false)
        if (state.successed? && !prerequisites_updated) || !needed?
          application.trace "** Skip #{name_with_params}" if application.options.trace
          state.ivar.try_set(false)
          return
        end

        if state.start_session
          begin
            async_execute_in_worker do
              begin
                execute(task_args)
                state.ivar.try_set(true)
              ensure
                state.close_session($ERROR_INFO)
              end
            end
          ensure
            state.close_session($ERROR_INFO) if $ERROR_INFO
          end
        else
          async_wait_complete
        end
      end

      def async_wait_complete
        unless application.options.wait_external_task
          err = RuntimeError.new("task #{name_with_params} already running")
          return state.ivar.try_fail(err)
        end

        application.trace "** Wait #{name_with_params}" if application.options.trace

        async_execute_in_worker(:waiter) do
          interval = application.options.wait_external_task_interval || 10
          timeout = application.options.wait_external_task_timeout || 3600
          timeout_tm = Time.now.to_f + timeout

          loop do
            state.reload
            if !state.running?
              state.ivar.try_set(true)
              break
            elsif Time.now.to_f >= timeout_tm
              state.ivar.try_fail(StandardError.new('timeout exceeded'))
              break
            else
              sleep interval
            end
          end
        end
      end

      def async_execute_in_worker(worker = nil, &block)
        application.worker[worker || self.worker].post do
          begin
            block.call
          rescue Exception => err
            state.ivar.try_fail(err)
          end
        end
      end
    end
  end
end
