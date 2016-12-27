require 'test_helper'

module Abid
  class TaskTest < AbidTest
    include Rake::DSL
    include Abid::DSL

    def setup
      play(:test) do
        param :date, type: :date
        attr_accessor :callback_called

        setup do
          needs :parent
        end

        before { self.callback_called = true }
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
      task = Abid.application.lookup(:test)
      assert_nil task.play
    end

    def test_lookup
      task = Abid.application[:test, date: '2016-01-01']

      assert_kind_of Abid::Task, task
      assert_equal Date.new(2016, 1, 1), task.play.date
      assert_equal task.play.date, task.prerequisite_tasks.first.play.date
    end

    def test_relative_name
      task_1 = Abid.application['ns:task_1']
      task_2 = Abid.application['ns:task_2']
      task_3 = Abid.application['ns:task_3']

      assert_equal task_1.play_class, task_2.play_class.superclass
      assert_equal task_1.play_class, task_3.prerequisite_tasks.first.play_class
    end

    def test_name_with_args
      unbound_task = Abid.application.lookup(:test)
      assert_equal 'test date:date', unbound_task.name_with_args

      task = Abid.application[:test, date: '2016-01-01']
      assert_equal 'test date=2016-01-01', task.name_with_args
      end

    def test_callback
      task = Abid.application[:test, date: '2016-01-01']
      play = task.play
      Engine.invoke(Job.find_by_task(task))

      assert play.callback_called
    end
  end
end
