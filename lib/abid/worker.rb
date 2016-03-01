module Abid
  class Worker
    def initialize(application)
      @application = application
      @pools = {}
      @pool_definitions = {}

      @pool_definitions[:waiter] = nil
      @pools[:waiter] = Concurrent::SimpleExecutorService.new

      if application.options.always_multitask
        default_thread_num = @application.options.thread_pool_size || \
                             Rake.suggested_thread_count - 1
      else
        default_thread_num = 1
      end
      define(:default, default_thread_num)
    end

    def define(name, thread_count)
      name = name.to_sym
      fail "worker #{name} already defined" if @pool_definitions.include?(name)
      @pool_definitions[name] = thread_count
    end

    def [](name)
      unless @pool_definitions.include?(name)
        fail "worker #{name} is not defined"
      end

      @pools[name] ||= Concurrent::FixedThreadPool.new(
        @pool_definitions[name],
        idletime: FIXNUM_MAX
      )
    end
    def shutdown
      @pools.each do |_, pool|
        pool.shutdown
        pool.wait_for_termination
      end
    end

    def kill
      @pools.each do |_, pool|
        pool.kill
      end
    end
  end
end
