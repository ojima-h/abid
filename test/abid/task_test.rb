require 'test_helper'

module Abid
  class TaskTest < AbidTest
    include Abid::DSL

    def setup
      play(:test) do
        param :date, type: :date

        def setup
          needs :parent
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
    end
  end
end
