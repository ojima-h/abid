require 'test_helper'

module Abid
  module DSL
    class PlayTest < AbidTest
      def test_play_settings
        t = env.application['test_dsl:p1']
        j = env.job_manager.find_by_task(t, i: 0, j: 1)
        play = j.task.instance_eval { @play }

        assert_equal 0, play.i
        assert_equal 1, play.j

        assert_equal true, play.s1
        assert_equal 0, play.s2
        assert_equal 1, play.s3
        assert_equal 2, play.s4
        assert_equal 3, play.s5
      end

      def test_play_prerequisites
        t = env.application['test_dsl:p1']
        j = env.job_manager.find_by_task(t, i: 0, j: 1)
        j.invoke

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
        t = env.application['test_dsl:p2']

        assert_raises RuntimeError, /param p2 is not specified/ do
          env.job_manager.find_by_task(t)
        end

        j = env.job_manager.find_by_task(t, p2: -1)
        play = j.task.instance_eval { @play }
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
        t = env.application['test_dsl:p2']
        env.job_manager.find_by_task(t, p2: 0).invoke
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
        t = env.application['test_dsl:p3']
        j = env.job_manager.find_by_task(t)
        play = j.task.instance_eval { @play }
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
    end
  end
end
