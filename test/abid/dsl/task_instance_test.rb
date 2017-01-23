require 'test_helper'

module Abid
  module DSL
    class TaskInstanceTest < AbidTest
      def test_after_hook
        invoke('test_dsl:p4')

        tag, err = AbidTest.history.first

        assert_equal 'test_dsl:p4.after', tag
        assert_equal RuntimeError, err.class
        assert_equal 'test', err.message
      end
    end
  end
end
