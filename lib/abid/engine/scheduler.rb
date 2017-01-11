require 'concurrent/atomic/atomic_fixnum'

module Abid
  module Engine
    # Scheduler operates whole job flow execution.
    class Scheduler
      # @return [void]
      def self.invoke(job, *args, invocation_chain: nil)
        task_args = Rake::TaskArguments.new(job.task.arg_names, args)
        invocation_chain ||= Rake::InvocationChain::EMPTY

        detect_circular_dependency(job, invocation_chain)
        new(job, task_args, invocation_chain).invoke
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

      def self.detect_circular_dependency(job, chain)
        # raise error if job.task is a member of the chain
        new_chain = Rake::InvocationChain.append(job.task, chain)

        job.prerequisites.each do |preq_job|
          detect_circular_dependency(preq_job, new_chain)
        end
      end

      def initialize(job, args, invocation_chain)
        @job = job
        @args = args
        @chain = invocation_chain.conj(@job.task)
        @executor = Executor.new(job, args)
      end

      def invoke
        return unless @executor.prepare

        trace_invoke
        attach_chain
        invoke_prerequisites
        after_prerequisites do
          @executor.capture_exception do
            @executor.start
          end
        end
      end

      private

      def trace_invoke
        return unless @job.env.options.trace
        @job.env.application.trace \
          "** Invoke #{@job.task.name} #{@job.task.format_trace_flags}"
      end

      def attach_chain
        @job.process.add_observer do
          error = @job.process.error
          next if error.nil?
          next if @chain.nil?

          error.extend(Rake::InvocationExceptionMixin) unless
            error.respond_to?(:chain)
          error.chain ||= @chain
        end
      end

      def invoke_prerequisites
        @job.prerequisites.each do |preq_job|
          preq_args = @args.new_scope(@job.task.arg_names)
          Scheduler.new(preq_job, preq_args, @chain).invoke
        end
      end

      def after_prerequisites(&block)
        counter = DependencyCounter.new(@job.prerequisites.size, &block)
        @job.prerequisites.each do |preq_job|
          preq_job.process.add_observer counter
        end
      end
    end
  end
end