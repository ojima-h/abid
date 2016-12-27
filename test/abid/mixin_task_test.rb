require 'test_helper'

module Abid
  class MixinTaskTest < AbidTest
    module Sample
      def name
        'normal_module'
      end

      def attr_1
        10
      end
    end

    include Rake::DSL
    include Abid::DSL

    def setup
      namespace :ns0 do
        namespace :ns do
          mixin :mixin_0 do
            set :attr_0, -1
          end

          mixin :mixin_1 do
            include :mixin_0

            set :name, 'mixin_1'
            set :attr_2, 30

            param :param_1, type: :int
            param :param_3, type: :int, default: 0
          end

          mixin :mixin_2 do
            set :name, 'mixin_2'
          end
        end

        play :task do
          include 'ns:mixin_1'
          include Sample
          include 'ns:mixin_2'

          param :param_2, type: :int
          param :param_3, type: :int, default: 3
        end
      end
    end

    def test_mixin
      task = Abid.application['ns0:task', param_1: 1, param_2: 2]

      assert 'mixin_2', task.play.name
      assert -1, task.play.attr_0
      assert 10, task.play.attr_1
      assert 30, task.play.attr_2
      assert 1, task.play.param_1
      assert 2, task.play.param_2
      assert 3, task.play.param_3

      assert_raises do
        Abid.application['ns0:task', param_2: 2]
      end
    end
  end
end
