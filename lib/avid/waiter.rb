module Avid
  # non-block waiter
  class Waiter
    Entry = Struct.new(:ivar, :start_time, :next_time,
                       :interval, :timeout, :block)

    def initialize
      @cv = ConditionVariable.new
      @mutex = Mutex.new
      @queue = MultiRBTree.new
      @thread = nil
      @error = nil
    end

    def wait(interval: 5, timeout: 60, &block)
      run_thread

      ivar = Concurrent::IVar.new
      now = Time.now.to_f
      next_time = now + interval
      push(Entry.new(ivar, now, next_time, interval, timeout, block))
      ivar
    end

    def shutdown(error = nil)
      error ||= RuntimeError.new('waiter is shutting down')
      @mutex.synchronize do
        @error = error
        @queue.each { |_, e| e.ivar.fail(error) }
        @queue.clear
      end
    end

    def empty?
      @queue.empty?
    end

    def alive?
      @thread.alive?
    end

    private

    def push(entry)
      @mutex.synchronize do
        fail @error if @error

        @queue[entry.next_time] = entry
        @cv.signal
      end
    end

    def shift
      _, e = @mutex.synchronize do
        @cv.wait(@mutex) while @queue.empty?
        @queue.shift
      end
      e
    end

    def sleep_until_next_time(entry)
      sleep_time = entry.next_time - Time.now.to_f
      return true if sleep_time <= 0

      @mutex.synchronize do
        @cv.wait(@mutex, sleep_time)

        entry.next_time <= Time.now.to_f
      end
    end

    def proc_entry(entry)
      unless sleep_until_next_time(entry)
        # failed to wait. retry.
        push(entry)
        return
      end

      return if entry.ivar.complete? # canceled

      now = Time.now.to_f
      elapsed = now - entry.start_time
      ret = entry.block.call(elapsed)
      if ret
        entry.ivar.set(ret)
      elsif entry.timeout > 0 && entry.timeout < elapsed
        fail 'timeout exceeded'
      else
        entry.next_time = now + entry.interval
        push(entry)
      end
    rescue Exception => err
      begin
        entry.ivar.fail(err)
      rescue Concurrent::MultipleAssignmentError
        nil
      end
    end

    def run_thread
      return if @thread

      @thread = Thread.new do
        begin
          proc_entry(shift) while @error.nil?
        ensure
          shutdown($ERROR_INFO) if $ERROR_INFO
        end
      end
    end
  end
end
