module Abid
  class Session
    extend MonitorMixin

    attr_reader :updated, :successed, :failed, :error
    alias_method :updated?, :updated
    alias_method :successed?, :successed
    alias_method :failed?, :failed

    def initialize(task)
      @task = task
      @state = task.state

      @entered = false
      @locked = false
      @updated = false
      @successed = false
      @failed = false
      @error = nil
      @ivar = Concurrent::IVar.new
    end

    def synchronize(&block)
      self.class.synchronize(&block)
    end

    def enter(&block)
      capture_exception do
        synchronize do
          return @ivar if @entered
          @entered = true
        end
        block.call
      end
      @ivar
    end

    def capture_exception(&block)
      block.call
      finished = true
    rescue Exception => e
      self.fail(e)
    ensure
      if e.nil? && !finished
        fail 'thread killed' rescue self.fail($ERROR_INFO)
      end
    end

    def add_observer(*args, &block)
      @ivar.add_observer(*args, &block)
    end

    def lock
      synchronize do
        @state.start unless @locked
        @locked = true
        true
      end
    rescue AbidErrorTaskAlreadyRunning
      false
    end

    def unlock(error = nil)
      synchronize do
        @state.finish(error) if @locked
        @locked = false
      end
    end

    def success
      @successed = true
      @updated = true
      unlock
      @ivar.try_set(true)
    end

    def skip
      @successed = true
      @updated = false
      unlock
      @ivar.try_set(false)
    end

    def fail(error)
      @failed = true
      @error = error
      unlock(error)
      @ivar.fail(error) rescue Concurrent::MultipleAssignmentError
    rescue Exception => e
      @ivar.fail(e) rescue Concurrent::MultipleAssignmentError
    end
  end
end
