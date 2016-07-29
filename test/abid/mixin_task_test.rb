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
      namespace :ns do
        mixin :mixin_1 do
          set :name, 'mixin_1'
          set :attr_2, 30
        end

        mixin :mixin_2 do
          set :name, 'mixin_2'
        end
      end

      play :task do
        include 'ns:mixin_1'
        include Sample
        include 'ns:mixin_2'
      end
    end

    def test_mixin
      task = app['task']

      assert 'mixin_2', task.play.name
      assert 10, task.play.attr_1
      assert 30, task.play.attr_2
    end
  end
end
