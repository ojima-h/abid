require 'test_helper'

module Abid
  module DSL
    class PlayTest < AbidTest
      def find_play(name, params = {})
        env.application.abid_task_manager.resolve(name, params).send(:play)
      end

      def test_play_settings
        play = find_play('test_dsl:p1', i: 0, j: 1)

        assert_equal 0, play.i
        assert_equal 1, play.j

        assert_equal true, play.s1
        assert_equal 0, play.s2
        assert_equal 1, play.s3
        assert_equal 2, play.s4
        assert_equal 3, play.s5
      end

      def test_play_prerequisites
        invoke('test_dsl:p1', i: 0, j: 1)

        assert_equal [
          ['test_dsl:p1_2', 0],
          ['test_dsl:ns:m1_1'],
          ['test_dsl:p1_3', 0],
          ['test_dsl:p1_3', 1],
          ['test_dsl:p1', 0],
          ['test_dsl:p1.after']
        ], AbidTest.history
      end

      def test_overwrite
        err = assert_raises RuntimeError do
          env.application.abid_task_manager.resolve('test_dsl:p2', {})
        end
        assert_match(/param p2 is not specified/, err.message)

        play = find_play('test_dsl:p2', p2: -1)
        assert_equal :m2_1, play.class.h1
        assert_equal :m2_0, play.class.h2
        assert_equal 1, play.p1
        assert_equal(-1, play.p2)
        assert_equal(-2, play.p3)
        assert_equal :m2_1, play.s1
        assert_equal :m2_2, play.s2
        assert_equal :m2_1, play.s3
        refute_includes play.class.params_spec.to_h, :p3
      end

      def test_actions
        invoke('test_dsl:p2', p2: 0)
        assert_equal [
          ['test_dsl:ns:m2_0.setup'],
          ['test_dsl:ns:m2_1.setup'],
          ['test_dsl:ns:m2_2.setup'],
          ['test_dsl:ns:m2_0.after'],
          ['test_dsl:ns:m2_1.after'],
          ['test_dsl:ns:m2_2.after']
        ], AbidTest.history
      end

      def test_undef_param
        play = find_play('test_dsl:p3')
        params_spec = play.class.params_spec.to_h

        %w(p1 p2 p3).each do |v|
          assert_raises NoParamError do
            play.send(v.to_sym)
          end
        end
        refute_includes params_spec, :p1
        refute_includes params_spec, :p2
        refute_includes params_spec, :p3
        assert_respond_to play, :s1
        assert_respond_to play, :s2
        assert_respond_to play, :s3
      end

      def test_action
        invoke('test_dsl:p5')
        assert_equal [
          ['test_dsl:ns:m5'],
          ['test_dsl:p5']
        ], AbidTest.history
      end
    end
  end
end
