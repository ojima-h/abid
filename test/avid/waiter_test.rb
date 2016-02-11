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
  end
end
