require 'concurrent/atomic/atomic_fixnum'

module Abid
  class Engine
    # Scheduler operates whole job flow execution.
    class Scheduler
      # @return [void]
      def self.invoke(process, *args, invocation_chain: nil)
        task_args = Rake::TaskArguments.new(process.job.arg_names, args)
        invocation_chain ||= Rake::InvocationChain::EMPTY

        detect_circular_dependency(process, invocation_chain)
        new(process, task_args, invocation_chain).invoke
      end

      # @!visibility private

      # Execute given block when DependencyCounter#update is called `count`
      # times.
      class DependencyCounter
        def initialize(count, &block)
          @counter = Concurrent::AtomicFixnum.new(count)
          @block = block
          yield if count <= 0
        end

        def update(*_)
          @block.call if @counter.decrement.zero?
        end
      end

      def self.detect_circular_dependency(process, chain)
        # raise error if process.job is a member of the chain
        new_chain = Rake::InvocationChain.append(process.job, chain)

        process.prerequisites.each do |preq_process|
          detect_circular_dependency(preq_process, new_chain)
        end
      end

      def initialize(process, args, invocation_chain)
        @process = process
        @args = args
        @chain = invocation_chain.conj(@process.job)
        @executor = Executor.new(process, args)
      end

      def invoke
        return unless @executor.prepare

        @process.job.trace_invoke
        attach_chain
        invoke_prerequisites
        after_prerequisites do
          @process.capture_exception do
            @executor.start
          end
        end
      end

      private

      def attach_chain
        @process.on_complete do
          error = @process.error
          next if error.nil?
          next if @chain.nil?

          error.extend(Rake::InvocationExceptionMixin) unless
            error.respond_to?(:chain)
          error.chain ||= @chain
        end
      end

      def invoke_prerequisites
        @process.prerequisites.each do |preq|
          preq_args = @args.new_scope(@process.job.arg_names)
          Scheduler.new(preq, preq_args, @chain).invoke
        end
      end

      def after_prerequisites(&block)
        counter = DependencyCounter.new(@process.prerequisites.size, &block)
        @process.prerequisites.each do |preq|
          preq.on_complete { counter.update }
        end
      end
    end
  end
end
