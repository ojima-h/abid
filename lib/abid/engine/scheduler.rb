require 'concurrent/atomic/atomic_fixnum'

module Abid
  module Engine
    # @!visibility priate

    # Scheduler is
    class Scheduler
      # fuga
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

      def self.invoke(job)
        new(job).invoke
        job.process.wait
      end

      def initialize(job)
        @job = job
        @prerequisites = job.prerequisites
        @processes = job.prerequisites.map(&:process)
        @fixed = false
      end

      def invoke(invocation_chain = nil)
        trace_invoke
        append_to_chain(invocation_chain || Rake::InvocationChain::EMPTY)
        attach_chain
        precheck
        invoke_prerequisites
        after_prerequisites do
          check
          execute_job
        end
      end

      private

      def trace_invoke
        return unless Abid.application.options.trace
        Abid.application.trace \
          "** Invoke #{@ob.task.name} #{@ob.task.format_trace_flags}"
      end

      def append_to_chain(invocation_chain)
        @chain = invocation_chain.conj(@job.task)
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

      def precheck
        state = @job.state
        precheck_fail(state)
        precheck_skip(state)
        precheck_dependency
      end

      def precheck_fail(state)
        return if @fixed
        return if Abid.application.options.repair
        return unless state.failed?
        return if @chain.tail.empty? # if invoked directly
        @job.process.fail Error.new('task has been failed')
        @fixed = true
      end

      def precheck_skip(state)
        return if @fixed
        return if Abid.application.options.repair && !@prerequisites.empty?
        return unless state.successed?
        @job.process.skip
        @fixed = true
      end

      # detect circular dependency
      def precheck_dependency
        return if @fixed

        @prerequisites.each do |preq_job|
          next unless @chain.member?(preq_job.task)

          msg = "Circular dependency detected: #{@chain} => #{preq_job.task}"
          @job.process.fail RuntimeError.new(msg)
          @fixed = true
          break
        end
      end

      def invoke_prerequisites
        return if @fixed

        @prerequisites.each do |preq_job|
          Scheduler.new(preq_job).invoke(@chain)
        end
      end

      def after_prerequisites(&block)
        return if @fixed

        counter = DependencyCounter.new(@prerequisites.size, &block)
        @prerequisites.each do |preq_job|
          preq_job.process.add_observer counter
        end
      end

      def check
        check_cancel
        check_skip
      rescue => e
        @job.process.fail(e)
      end

      def check_cancel
        return if @fixed
        return if @prerequisites.empty?
        return if !@processes.any? { |p| p.result == :failed } \
                  && !@processes.any? { |p| p.result == :cancelled }
        @job.process.cancel
        @fixed = true
      end

      def check_skip
        return if @fixed
        return if @prerequisites.empty?
        return unless Abid.application.options.repair
        return if @processes.any? { |p| p.result == :successed }
        @job.process.skip
        @fixed = true
      end

      def execute_job
        return if @fixed
        @job.process.execute
        @fixed = true
      end
    end
  end
end
