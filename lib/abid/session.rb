require 'concurrent/hash'

module Abid
  class Session
    extend MonitorMixin

    %w(successed skipped failed canceled).each do |result|
      define_method(:"#{result}?") { @result == result.to_sym }
    end
    attr_reader :error

    def self.current_sessions
      @current_sessions ||= Concurrent::Hash.new
    end

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
      return true if state_disabled? || state_preview?

      synchronize do
        @state.start unless @locked
        @locked = true
        self.class.current_sessions[object_id] = self
        true
      end
    rescue AlreadyRunningError
      false
    end

    def unlock(error = nil)
      return if state_disabled? || state_preview?

      synchronize do
        @state.finish(error) if @locked
        @locked = false
        self.class.current_sessions.delete(object_id)
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

    def state_disabled?
      @task.volatile? || Rake.application.options.disable_state
    end

    def state_preview?
      Rake.application.options.dryrun || Rake.application.options.preview
    end
  end
end
