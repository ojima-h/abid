require 'test_helper'
require 'concurrent/atomic/atomic_fixnum'

module Abid
  module Engine
    class WorkerManagerTest < AbidTest
      def test_shutdown
        worker_manager = WorkerManager.new
        worker_manager.define(:test, 2)

        ret = Concurrent::AtomicFixnum.new(0)
        10.times do
          worker_manager[:test].post do
            sleep 0.1
            ret.increment
          end
        end

        assert worker_manager.shutdown
        assert_equal 10, ret.value
      end

      def test_kill
        worker_manager = WorkerManager.new
        worker_manager.define(:test, 2)

        killed = false
        worker_manager[:test].post do
          begin
            sleep
          ensure
            killed = true
          end
        end

        refute worker_manager.shutdown(1)
        refute killed

        assert worker_manager.kill
        sleep 0.1
        assert killed
      end

      def test_execute_task
        Engine.invoke(Job['test_worker:p1'])

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

      def test_simple_executor
        Engine.invoke(Job['test_worker:p2'])

        t = []
        AbidTest.history.each do |name, params|
          t << params[:thread] if name == 'test_worker:p2_i'
        end

        assert_equal 10, t.length
        assert_equal 10, t.uniq.length
      end
    end
  end
end
