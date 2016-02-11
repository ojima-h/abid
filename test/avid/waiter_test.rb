require 'test_helper'

module Avid
  class WaiterTest < AvidTest
    def setup
      @waiter = Waiter.new
    end

    def teardown
      @waiter.shutdown
    end

    def test_success
      ivar = @waiter.wait(interval: 0.1) { |e| e > 0.1 }
      assert_equal :pending, ivar.state
      ivar.wait!
      assert @waiter.empty?
      assert @waiter.alive?
    end

    def test_error
      ivar = @waiter.wait(interval: 0.1) { |e| fail if e > 0.1 }
      assert_equal :pending, ivar.state
      assert_raises(RuntimeError) { ivar.wait! }
      assert @waiter.empty?
      assert @waiter.alive?
    end

    def test_retry
      spy = []
      ivar1 = @waiter.wait(interval: 0.5) { |e| spy << 1 if e > 0.5 }
      sleep 0.1
      ivar2 = @waiter.wait(interval: 0.1) { |e| spy << 2 if e > 0.2 }

      ivar1.wait!
      ivar2.wait!

      assert_equal [2, 1], spy
    end
  end
end
