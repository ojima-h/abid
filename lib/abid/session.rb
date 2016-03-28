module Abid
  class Session
    extend MonitorMixin

    %w(successed skipped failed canceled).each do |result|
      define_method(:"#{result}?") { @result == result.to_sym }
    end
    attr_reader :error

    def initialize(task)
      @task = task
      @state = task.state

      @entered = false
      @locked = false
      @result = nil
      @error = nil
      @ivar = Concurrent::IVar.new

      @on_success = []
      @on_fail = []
    end

    def synchronize(&block)
      self.class.synchronize(&block)
    end

    def enter(&block)
      synchronize do
        return @ivar if @entered
        @entered = true
      end
      block.call
      @ivar
    end

    def capture_exception(&block)
      block.call
    rescue Exception => e
      self.fail(e)
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
      unlock
      @result = :successed
      @ivar.try_set(true)
    end

    def skip
      unlock
      @result = :skipped
      @ivar.try_set(false)
    end

    def fail(error)
      @result = :failed
      @error = error
      unlock(error)
      @ivar.fail(error) rescue Concurrent::MultipleAssignmentError
    rescue Exception => e
      @ivar.fail(e) rescue Concurrent::MultipleAssignmentError
    end

    def cancel(error)
      unlock(error)
      @result = :canceled
      @error = error
      @ivar.fail(error) rescue Concurrent::MultipleAssignmentError
    end
  end
end
