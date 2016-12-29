require 'test_helper'

module Abid
  module Engine
    class WaiterTest < AbidTest
      def test_success
        es = []
        ivar = Waiter.wait(interval: 0.1) { |e| es << e; e > 0.2 }
        assert ivar.value!
        assert 0 < es.max && es.max < 1
      end

      def test_timeout
        ivar = Waiter.wait(interval: 0.1, timeout: 0.2) { false }
        refute ivar.value!
      end

      def test_error
        ivar = Waiter.wait(interval: 0.1) { |e| raise 'test' if e > 0.2 }
        assert_raises(RuntimeError, 'test') { ivar.value! }
      end

      def test_check_once
        ivar = Waiter.wait(interval: FIXNUM_MAX) { true }
        assert ivar.value!(60)
      end
    end
  end
end
