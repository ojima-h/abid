module Avid
  class TaskExecutor
    FIXNUM_MAX = (2**(0.size * 8 - 2) - 1) # :nodoc:

    attr_reader :application

    def initialize(application)
      @application = application
    end

    def workers
      @workers ||= {}
    end

    def define_worker(name, thread_count)
      name = name.to_sym

      fail "worker #{name} already defined" if @workers.include?(name)
      @workers[name] = Concurrent::FixedThreadPool.new(
        thread_count,
        idletime: FIXNUM_MAX
      )
    end

    def default_worker
      @default_worker ||= Concurrent::FixedThreadPool.new(
        application.options.thread_pool_size || Rake.suggested_thread_count - 1,
        idletime: FIXNUM_MAX
      )
    end

    def serial_worker
      @serial_worker ||= Concurrent::FixedThreadPool.new(
        1,
        idletime: FIXNUM_MAX
      )
    end

    def invoke(task, *args)
      task_args = TaskArguments.new(task.arg_names, args)
      invoke_with_call_chain(task, task_args, Rake::InvocationChain::EMPTY)
    end

    # Same as invoke, but explicitly pass a call chain to detect
    # circular dependencies.
    def invoke_with_call_chain(task, task_args, invocation_chain) # :nodoc:
      Concurrent::Promise.new.flat_map do
        new_chain = Rake::InvocationChain.append(task, invocation_chain)

        if application.options.trace
          application.trace "** Invoke #{name} #{format_trace_flags}"
        end

        next true_promise if already_invoked?(task)

        invoke_prerequisites(task, task_args, new_chain).flat_map do
          next true_promise unless task.needed?
          execute(task, args)
        end
      end
    end

    def true_promise
      @true_promise ||= Concurrent::Promise.fulfill(true)
    end

    # Invoke all the prerequisites of a task.
    def invoke_prerequisites(task, task_args, invocation_chain) # :nodoc:
      promises = task.prerequisite_tasks.map do |p|
        prereq_args = task_args.new_scope(p.arg_names)
        invoke_with_call_chain(p, prereq_args, invocation_chain)
      end

      Concurrent::Promise.zip(*promises)
    end

    def execute(task, args = nil)
      Promise.execute { task.execute(args) }
    end
  end
end
