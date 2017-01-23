require 'concurrent/configuration'
require 'concurrent/executor/cached_thread_pool'
require 'concurrent/executor/fixed_thread_pool'
require 'concurrent/executor/safe_task_executor'
require 'concurrent/executor/timer_set'

module Abid
  class Engine
    # WorkerManager manges thread pools definition, creation and termination.
    #
    #     worker_manager = Abid.global.worker_manager
    #
    #     worker_manager.define(:main, 2)
    #
    #     worker_manager[:main].post { :do_something }
    #
    #     worker_manager.shutdown
    class WorkerManager
      def initialize(env)
        @env = env
        @workers = {}

        initialize_builtin_workers
      end

      # Define new worker.
      def define(name, num_threads)
        if @workers.include?(name)
          raise Error, "worker #{name} is already defined"
        end

        @workers[name] = create_worker(num_threads: num_threads)
      end

      # Find or create worker
      #
      # @param name [String, Symbol] worker name
      # @return [Concurrent::ExecutorService]
      def [](name)
        unless @workers.include?(name)
          raise Error, "worker #{name} is not defined"
        end

        @workers[name]
      end

      def shutdown(timeout = nil)
        each_worker(&:shutdown)
        each_worker { |worker| worker.wait_for_termination(timeout) }
        each_worker.all?(&:shutdown?)
      end

      def kill
        each_worker(&:kill)
        true
      end

      def each_worker(&block)
        @workers.values.each(&block)
      end

      private

      def initialize_builtin_workers
        @workers[:default] = create_worker(num_threads: default_num_threads)
        @workers[:waiter] = Concurrent.new_io_executor
        @workers[:timer_set] =
          Concurrent::TimerSet.new(executor: @workers[:waiter])
      end

      def create_worker(definition)
        if definition[:num_threads] > 0
          Concurrent::FixedThreadPool.new(definition[:num_threads])
        else
          Concurrent::CachedThreadPool.new
        end
      end

      def default_num_threads
        if @env.options.always_multitask
          @env.options.thread_pool_size ||
            Rake.suggested_num_threads - 1
        else
          1
        end
      end
    end
  end
end
