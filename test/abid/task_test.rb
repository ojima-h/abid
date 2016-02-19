require 'test_helper'

module Abid
  class TaskTest < AbidTest
    include Rake::DSL
    include Abid::DSL

    def setup
      play(:test) do
        param :date, type: :date

        setup do
          needs :parent
        end
      end

      play(:parent) do
        param :date, type: :date
      end

      namespace :ns do
        play :task_1 do
        end

        play :task_2, extends: :task_1 do
        end

        play :task_3 do
          setup do
            needs :task_1
          end
        end
      end
    end

    def test_unbound_task
      task = app.lookup(:test)
      assert_nil task.play
    end

    def test_lookup
      task = app[:test, date: '2016-01-01']

      assert_kind_of Abid::Task, task
      assert_equal Date.new(2016, 1, 1), task.play.date
      assert_equal task.play.date, task.prerequisite_tasks.first.play.date
    end

    def test_relative_name
      task_1 = app['ns:task_1']
      task_2 = app['ns:task_2']
      task_3 = app['ns:task_3']

      assert_equal task_1.play_class, task_2.play_class.superclass
      assert_equal task_1.play_class, task_3.prerequisite_tasks.first.play_class
    end

    def test_name_with_args
      unbound_task = app.lookup(:test)
      assert_equal 'test date:date', unbound_task.name_with_args

      task = app[:test, date: '2016-01-01']
      assert_equal 'test date=2016-01-01', task.name_with_args
    end
  end
end
