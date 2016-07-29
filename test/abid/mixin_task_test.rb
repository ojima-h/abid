require 'test_helper'

module Abid
  class MixinTaskTest < AbidTest
    include Rake::DSL
    include Abid::DSL

    def setup
      namespace :ns do
        mixin :mixin_1 do
          set :name, 'mixin_1'
          set :age, 30
        end

        mixin :mixin_2 do
          set :name, 'mixin_2'
        end
      end

      play :task do
        include 'ns:mixin_1'
        include 'ns:mixin_2'
      end
    end

    def test_mixin
      task = app['task']

      assert 'mixin_2', task.play.name
      assert 30, task.play.age
    end
  end
end
