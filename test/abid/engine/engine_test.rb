require 'test_helper'

module Abid
  class EngineTest < AbidTest
    def test_preview
      in_options(preview: true) do
        invoke('test_dsl:p1', i: 0, j: 1)
      end

      assert_equal [
        ['test_dsl:p1_2', 0],
        ['test_dsl:ns:m1_1'],
        ['test_dsl:p1_3', 0],
        ['test_dsl:p1_3', 1],
        ['test_dsl:p1', 0],
        ['test_dsl:p1.after']
      ], AbidTest.history

      assert_empty env.state_manager.states.all
    end
  end
end
