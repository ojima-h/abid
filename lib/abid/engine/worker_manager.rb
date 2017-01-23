require 'forwardable'
require 'monitor'

require 'concurrent/delay'

module Abid
  module Engine
    # WorkerManager manges thread pools definition, creation and termination.
    #
    #     worker_manager = Abid.global.worker_manager
    #
    #     worker_manager.define(:main, 2)
    #
    #     worker_manager[:main].post { :do_something }
    #
    #     worker_manager.shutdown
    #
    # @todo Remove `@mon.synchronize`
    # @todo Remove Delay
    # @todo Remove #each_active
    class WorkerManager
      def initialize(env)
        @env = env
        @workers = {}
        @alive = true
        @mon = Monitor.new

        initialize_builtin_workers
      end

      # Define new worker.
      #
      # An actual worker is created when needed.
      def define(name, num_threads)
        @mon.synchronize do
          check_alive!

          if @workers.include?(name)
            raise Error, "worker #{name} is already defined"
          end

          @workers[name] = Concurrent::Delay.new do
            create_worker(num_threads: num_threads)
          end
        end
      end

      # Find or create worker
      #
      # @param name [String, Symbol] worker name
      # @return [Concurrent::ExecutorService]
      def [](name)
        @mon.synchronize do
          check_alive!

          unless @workers.include?(name)
            raise Error, "worker #{name} is not defined"
          end

          @workers[name].value!
        end
      end

      def shutdown(timeout = nil)
        @mon.synchronize do
          check_alive!
          each_active(&:shutdown)
          each_active { |worker| worker.wait_for_termination(timeout) }

          result = each_active.all?(&:shutdown?)
          @alive = false if result
          result
        end
      end

      def kill
        @mon.synchronize do
          check_alive!
          @alive = false
          each_active(&:kill)
        end
        true
      end

      private

      def initialize_builtin_workers
        @workers[:default] = Concurrent::Delay.new { create_default_worker }
        @workers[:waiter] = Concurrent::Delay.new { Concurrent.new_io_executor }
        @workers[:timer_set] = Concurrent::Delay.new do
          Concurrent::TimerSet.new(executor: self[:waiter])
        end
      end

      def create_worker(definition)
        if definition[:num_threads] > 0
          Concurrent::FixedThreadPool.new(definition[:num_threads])
        else
          Concurrent::CachedThreadPool.new
        end
      end

      def create_default_worker
        create_worker(num_threads: default_num_threads)
      end

      def default_num_threads
        if @env.options.always_multitask
          @env.options.thread_pool_size ||
            Rake.suggested_num_threads - 1
        else
          1
        end
      end

      def check_alive!
        raise Error, 'already terminated' unless @alive
      end

      # Iterate on active workers
      def each_active(&block)
        @workers.values.select(&:fulfilled?).map(&:value).each(&block)
      end
    end
  end
end
