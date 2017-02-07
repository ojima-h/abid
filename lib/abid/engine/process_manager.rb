require 'concurrent/atomic/atomic_reference'

module Abid
  class Engine
    # ProcessManager is a processes repositry and tracks each process progress.
    class ProcessManager
      def initialize(engine)
        @engine = engine
        @all = {}.compare_by_identity
        @actives = {}.compare_by_identity
        @top_levels = {}.compare_by_identity
        @summary = Hash.new { |h, k| h[k] = 0 }
        @errors = []
        @mon = Monitor.new
        @status = Concurrent::AtomicReference.new(:running)
      end
      attr_reader :summary, :errors

      def [](job)
        return @all[job] if @all.include?(job)

        @mon.synchronize do
          @all[job] ||= Process.new(@engine, job).tap do |process|
            process.on_update { update(process) }
          end
        end
      end

      # @param job [DSL::Job]
      # @param args [Array<Object>]
      # @return [Process]
      def invoke(job, args)
        raise Error, 'ProcessManager is not running now' unless running?

        process = self[job]
        @top_levels[process] = process
        Scheduler.invoke(process, *args)
        process.tap(&:wait)
      end

      # Update active processes list
      def update(process)
        update_actives(process)
        update_summary(process)
      end

      def shutdown
        return unless @status.compare_and_set(:running, :shuttingdown)
        actives.each(&:wait)
        @status.set(:shutdown)
      end

      # Kill all active processes
      # @param error [Exception] error reason
      def kill(error)
        return if shutdown?
        @status.set(:shutdown)
        @errors << error
        actives.each { |process| process.quit(error) }
      end

      def actives
        @actives.values
      end

      def active?(process)
        @actives.include?(process)
      end

      def root?(process)
        @top_levels.include?(process)
      end

      %w(running shuttingdown shutdown).each do |meth|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{meth}?
          @status.get == :#{meth}
        end
        RUBY
      end

      private

      def update_actives(process)
        if process.complete?
          @actives.delete(process)
        else
          @actives[process] = process
        end
      end

      def update_summary(process)
        return unless process.complete?
        return if process.job.dryrun?
        @mon.synchronize { @summary[process.status] += 1 }
        @errors << process.error if process.error
      end
    end
  end
end
