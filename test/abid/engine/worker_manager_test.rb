require 'test_helper'

require 'concurrent/ivar'
require 'concurrent/atomic/atomic_fixnum'
require 'concurrent/atomic/count_down_latch'

module Abid
  class Engine
    class WorkerManagerTest < AbidTest
      def setup
        @worker_manager = Abid::Environment.new.engine.worker_manager
      end

      def test_shutdown
        @worker_manager.define(:test, 2)

        ivar = Concurrent::IVar.new
        ret = Concurrent::AtomicFixnum.new(0)
        10.times do
          @worker_manager[:test].post do
            ret.increment
            ivar.wait # lock
          end
        end

        refute @worker_manager.shutdown(1)

        ivar.set true # unlock

        assert @worker_manager.shutdown(1)
        assert_equal 10, ret.value
      end

      def test_kill
        @worker_manager.define(:test, 2)

        ivar = Concurrent::IVar.new
        @worker_manager[:test].post do
          begin
            sleep
          ensure
            ivar.set true
          end
        end

        refute @worker_manager.shutdown(1)
        refute ivar.complete?

        assert @worker_manager.kill
        assert ivar.value(5), 'thread killed'
      end

      def test_cached_thraed_pool
        @worker_manager.define(:test, 0)

        ivar = Concurrent::IVar.new
        latch1 = Concurrent::CountDownLatch.new(10)
        latch2 = Concurrent::CountDownLatch.new(10)
        10.times do
          @worker_manager[:test].post do
            latch1.count_down
            ivar.wait # lock
            latch2.count_down
          end
        end

        assert latch1.wait(1), 'all tasks are started'
        refute latch2.wait(0.1), 'no tasks are finished'

        ivar.set true # unlock

        assert @worker_manager.shutdown(5)
        assert latch2.wait(1), 'all tasks are finished'
      end

      def test_execute_task
        invoke('test_worker:p1')

        t1 = []
        t2 = []
        AbidTest.history.each do |name, params|
          t1 << params[:thread] if name == 'test_worker:p1_1'
          t2 << params[:thread] if name == 'test_worker:p1_2'
        end

        assert(t1.length == 1, 'test_worker:p1_1 is executed once')
        assert(t2.length == 1, 'test_worker:p1_2 is executed once')
        assert(t1.first != t2.first, 'test_worker:p1_n is executed in each thread')
      end
    end
  end
end
