require 'concurrent/ivar'

module Abid
  module Engine
    class Waiter
      # Wait until the block returns truthy value.
      #
      # @param interval [Numeric]
      # @param timeout [Numeric]
      # @yieldparam elapsed_time [Numeric] elapsed time from started
      # @return [Concurrent::IVar] its value is false if timeout exceeded,
      #   otherwise true.
      def self.wait(interval: 5, timeout: 60, &block)
        new(interval, timeout, &block).wait
      end

      # @!visibility private

      def initialize(interval, timeout, &block)
        @interval = interval
        @timeout = timeout
        @start_time = Concurrent.monotonic_time
        @block = block
        @ivar = Concurrent::IVar.new
      end

      def wait
        wait_iter(0) # check immediately at first
        @ivar
      end

      private

      def elapsed_time
        Concurrent.monotonic_time - @start_time
      end

      def wait_iter(delay)
        result = WorkerManager[:timer_set].post(delay) do
          capture_exception do
            check_and_wait
          end
        end
        @ivar.fail(Concurrent::RejectedExecutionError.new) unless result
      end

      def check_and_wait
        if @block.call(elapsed_time)
          @ivar.set true
        elsif elapsed_time > @timeout
          @ivar.set false
        else
          wait_iter(@interval)
        end
      end

      def capture_exception
        yield
      rescue => error
        @ivar.fail error
      rescue Exception => exception
        # TODO: exit immediately
        @ivar.fail exception
      end
    end
  end
end
