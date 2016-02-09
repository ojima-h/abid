module Avid
  class TaskExecutor
    FIXNUM_MAX = (2**(0.size * 8 - 2) - 1) # :nodoc:

    attr_reader :application
    attr_reader :workers

    def initialize(application)
      @application = application
      @lock = Monitor.new
      @futures = {}
      @workers = {}

      define_worker(:default,
                    application.options.thread_pool_size || Rake.suggested_thread_count - 1)
      define_worker(:serial, 1)
    end

    def define_worker(name, thread_count)
      name = name.to_sym
      fail "worker #{name} already defined" if workers.include?(name)
      workers[name] = Concurrent::FixedThreadPool.new(
        thread_count,
        idletime: FIXNUM_MAX
      )
    end

    def worker_for(task)
      if task.is_a? Avid::Task
        name = (task.worker || :default).to_sym
        fail "worker #{name} is not defined" unless workers.include?(name)
        workers[name]
      else
        workers[:default]
      end
    end

    def shutdown
      workers.each do |_, worker|
        worker.shutdown
        worker.wait_for_termination
      end
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
        application.trace "** Invoke #{task.name}" if application.options.trace

        return @futures[task.object_id] if @futures.include?(task.object_id)

        state = State.find(task)
        if state.successed?
          application.trace "** Skip #{task.name}" if application.options.trace
          @futures[task.object_id] = Concurrent::Future.execute { false }
          return @futures[task.object_id]
        end

        executor = worker_for(task)

        preq_futures = invoke_prerequisites(task, task_args, new_chain)

        @futures[task.object_id] = Concurrent.dataflow_with!(
          executor,
          *preq_futures
        ) do
          state.session do
            execute(task, task_args) if task.needed?
          end
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
