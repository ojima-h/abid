require 'concurrent/atomic/atomic_fixnum'

module Abid
  module Engine
    # Scheduler builds whole job dependency graph, and execute jobs according to
    # the dependency.
    class Scheduler
      def self.invoke(job)
        detect_circular_dependency(job)
        new(job).invoke
        job.process.wait
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

      def self.detect_circular_dependency(job, chain = nil)
        chain ||= Rake::InvocationChain::EMPTY

        # raise error if job.task is a member of the chain
        new_chain = Rake::InvocationChain.append(job.task, chain)

        job.prerequisites.each do |preq_job|
          detect_circular_dependency(preq_job, new_chain)
        end
      end

      def initialize(job)
        @job = job
        @chain = nil
      end

      def invoke(invocation_chain = nil)
        return unless @job.process.prepare

        trace_invoke
        attach_chain(invocation_chain || Rake::InvocationChain::EMPTY)
        invoke_prerequisites
        after_prerequisites do
          @job.process.capture_exception do
            @job.process.start
          end
        end
      end

      private

      def trace_invoke
        return unless Abid.application.options.trace
        Abid.application.trace \
          "** Invoke #{@job.task.name} #{@job.task.format_trace_flags}"
      end

      def attach_chain(invocation_chain)
        @chain = invocation_chain.conj(@job.task)
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
          Scheduler.new(preq_job).invoke(@chain)
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
