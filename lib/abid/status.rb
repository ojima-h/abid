require 'concurrent/atomic/atomic_reference'
require 'concurrent/ivar'

module Abid
  class Status
    def initialize(initial_state)
      @state = Concurrent::AtomicReference.new(initial_state)
      @complete = Concurrent::IVar.new
      @observers = []
    end

    def get
      @state.get
    end

    def wait(timeout = nil)
      @complete.wait(timeout)
    end

    def compare_and_set(old_state, new_state, complete = false)
      return false unless @state.compare_and_set(old_state, new_state)
      if complete
        @complete.set([old_state, new_state])
      else
        notify_observers(old_state, new_state)
      end
      true
    end

    def try_set(new_state, complete = false)
      old_state = @state.get_and_set(new_state)
      if complete
        @complete.try_set([old_state, new_state])
      else
        notify_observers(old_state, new_state)
      end
      new_state
    end

    def complete?
      @complete.complete?
    end

    # @yieldparam old_state [Object]
    # @yieldparam new_state [Object]
    def on_complete
      @complete.add_observer do |_time, (old_state, new_state), _reason|
        yield(old_state, new_state)
      end
    end

    # @yieldparam old_state [Object]
    # @yieldparam new_state [Object]
    def on_update(&block)
      @observers << block
      on_complete(&block)
    end

    def notify_observers(old_state, new_state)
      @observers.each { |block| block.call(old_state, new_state) }
    end
  end
end
