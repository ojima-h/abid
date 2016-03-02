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
          async_invoke_with_prerequisites(task_args, new_chain)
        end
        state.ivar
      ensure
        state.ivar.try_fail($ERROR_INFO) if $ERROR_INFO
      end

      def async_invoke_with_prerequisites(task_args, invocation_chain)
        unless application.options.repair
          if state.successed?
            state.ivar.try_set(false)
            return # skip if successed
          elsif state.failed? && !invocation_chain.empty?
            # fail if not top level
            fail 'task has been failed' rescue state.ivar.try_fail($ERROR_INFO)
            return
          end
        end

        application.trace "** Invoke #{name_with_params}" if application.options.trace

        volatiles, non_volatiles = prerequisite_tasks.partition(&:volatile?)

        async_invoke_tasks(non_volatiles, task_args, invocation_chain) do |updated|
          if state.successed? && !updated
            application.trace "** Skip #{name_with_params}" if application.options.trace
            state.ivar.try_set(false)
          else
            async_invoke_tasks(volatiles, task_args, invocation_chain) do
              async_execute_with_session(task_args)
            end
          end
        end
      end

      def async_invoke_tasks(tasks, task_args, invocation_chain, &block)
        ivars = tasks.map do |t|
          args = task_args.new_scope(t.arg_names)
          t.async_invoke_with_call_chain(args, invocation_chain)
        end

        if ivars.empty?
          block.call(false)
        else
          counter = Concurrent::DependencyCounter.new(ivars.size) do
            begin
              if ivars.any?(&:rejected?)
                state.ivar.try_fail(ivars.find(&:rejected?).reason)
              else
                updated = ivars.map(&:value).any?
                block.call(updated)
              end
            rescue Exception => err
              state.ivar.try_fail(err)
            end
          end
          ivars.each { |i| i.add_observer counter }
        end
      end

      def async_execute_with_session(task_args)
        async_execute_in_worker do
          begin
            state.session do
              begin
                execute(task_args) if needed?
                finished = true
              ensure
                fail 'thread killed' if $ERROR_INFO.nil? && !finished
              end
            end

            state.ivar.try_set(true)
          rescue AbidErrorTaskAlreadyRunning
            async_wait_complete
          end
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
