module Abid
  class Worker
    def initialize(application)
      @application = application
      @pools = {}
      @pool_definitions = {}

      if application.options.always_multitask
        default_thread_num = @application.options.thread_pool_size || \
                             Rake.suggested_thread_count - 1
      else
        default_thread_num = 1
      end
      define(:default, default_thread_num)

      define(:fresh, -1)
    end

    def define(name, thread_count)
      name = name.to_sym
      fail "worker #{name} already defined" if @pool_definitions.include?(name)
      @pool_definitions[name] = thread_count
    end

    def [](name)
      return @pools[name] if @pools.include?(name)
      return self[:fresh] if name == :waiter # alias

      unless @pool_definitions.include?(name)
        fail "worker #{name} is not defined"
      end

      if @pool_definitions[name] > 0
        @pools[name] = Concurrent::FixedThreadPool.new(
          @pool_definitions[name],
          idletime: FIXNUM_MAX
        )
      else
        @pools[name] = Concurrent::SimpleExecutorService.new
      end
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
