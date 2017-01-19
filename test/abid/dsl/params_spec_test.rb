require 'test_helper'

module Abid
  module DSL
    class ParamsSpecTest < AbidTest
      def setup
        @play_class = env.application['test_dsl:p2'].internal
      end

      def test_fetch
        assert_equal({ default: 1 }, @play_class.params_spec[:p1])
        assert_equal({}, @play_class.params_spec[:p2])
        assert_equal({ default: :m2_1 }, @play_class.params_spec[:s3])
      end

      def test_to_h
        assert_equal(
          { p1: { default: 1 }, p2: {}, s3: { default: :m2_1 } },
          @play_class.params_spec.to_h
        )
      end

      def test_delete
        @play_class.params_spec.delete(:p1)
        assert_equal(
          { p2: {}, s3: { default: :m2_1 } },
          @play_class.params_spec.to_h
        )
      end
    end
  end
end
