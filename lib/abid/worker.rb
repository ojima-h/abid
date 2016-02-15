module Avid
  class Worker
    def initialize(application)
      @application = application
      @pools = {}

      default_thread_num = @application.options.thread_pool_size || \
                           Rake.suggested_thread_count - 1
      @pools[:default] = Concurrent::FixedThreadPool.new(
        default_thread_num,
        idletime: FIXNUM_MAX
      )

      @pools[:waiter] = Concurrent::SimpleExecutorService.new
    end

    def define(name, thread_count)
      name = name.to_sym
      fail "worker #{name} already defined" if @pools.include?(name)
      @pools[name] = Concurrent::FixedThreadPool.new(
        thread_count,
        idletime: FIXNUM_MAX
      )
    end

    def [](name)
      name = (name || :default).to_sym
      fail "worker #{name} is not defined" unless @pools.include?(name)
      @pools[name]
    end

    def shutdown
      @pools.each do |_, pool|
        pool.shutdown
        pool.wait_for_termination
      end
    end
  end
end
