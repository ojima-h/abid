require 'monitor'

module Abid
  module Engine
    class ProcessManager
      attr_reader :active_processes

      # @param env [Environment] abid environment
      def initialize(env)
        @env = env
        @active_processes = {}.compare_by_identity
        @mon = Monitor.new
      end

      # @return [Process] new process
      def create
        Process.new(self)
      end

      # Update active process set.
      # @param process [Process]
      def update(process)
        case process.status
        when :pending, :running
          add_active(process)
        when :complete
          delete_active(process)
        end
      end

      # Kill all active processes
      # @param error [Exception] error reason
      def kill(error)
        each_active { |p| p.quit(error) }
      end

      def active?(process)
        @mon.synchronize { @active_processes.include? process }
      end

      private

      def add_active(process)
        @mon.synchronize { @active_processes[process] ||= process }
      end

      def delete_active(process)
        @mon.synchronize { @active_processes.delete(process) }
      end

      def each_active(&block)
        @mon.synchronize { @active_processes.values.each(&block) }
      end
    end
  end
end
