module Avid
  class TaskExecutor
    attr_reader :application

    def initialize(application)
      @application = application
      @lock = Monitor.new
      @futures = {}
    end

    def invoke(task, *args)
      task_args = Rake::TaskArguments.new(task.arg_names, args)
      invoke_with_call_chain(task, task_args, Rake::InvocationChain::EMPTY).value!
    end

    # Same as invoke, but explicitly pass a call chain to detect
    # circular dependencies.
    def invoke_with_call_chain(task, task_args, invocation_chain) # :nodoc:
      new_chain = Rake::InvocationChain.append(task, invocation_chain)
      @lock.synchronize do
        return @futures[task.object_id] if @futures.include?(task.object_id)

        executor = application.worker[(task.is_a?(Avid::Task) && task.worker ? task.worker : :default)]
        state = State.find(task)

        # check if running
        if application.options.wait_external_task && state.running?
          application.trace "** Wait #{task.name}" if application.options.trace
          interval = application.options.wait_external_task_interval || 10
          timeout = application.options.wait_external_task_timeout || 3600
          @futures[task.object_id] = application.wait(
            interval: interval,
            timeout: timeout
          ) do
            state.reload
            fail 'external task failed' if state.failed?
            state.successed?
          end
          return @futures[task.object_id]
        end

        # check if successed
        if !application.options.check_prerequisites && state.successed?
          application.trace "** Skip #{task.name}" if application.options.trace
          @futures[task.object_id] = Concurrent::Future.execute { false }
          return @futures[task.object_id]
        end

        application.trace "** Invoke #{task.name}" if application.options.trace

        preq_futures = invoke_prerequisites(task, task_args, new_chain)

        @futures[task.object_id] = Concurrent.dataflow_with!(
          executor,
          *preq_futures
        ) do |*rets|
          if application.options.check_prerequisites && \
             !state.revoked? && \
             !rets.any? # if all the prerequesites are skipped
            application.trace "** Skip #{task.name}" if application.options.trace
            next false
          end

          state.session do
            execute(task, task_args) if task.needed?
          end
          true
        end
      end
    end

    # Invoke all the prerequisites of a task.
    def invoke_prerequisites(task, task_args, invocation_chain) # :nodoc:
      task.prerequisite_tasks.map do |p|
        prereq_args = task_args.new_scope(p.arg_names)
        invoke_with_call_chain(p, prereq_args, invocation_chain)
      end
    end

    def execute(task, args = nil)
      task.execute(args)
    end
  end
end
