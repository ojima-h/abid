require 'test_helper'

module Avid
  class TaskExecutorTest < AvidTest
    include Rake::DSL
    include Avid::DSL

    def setup
      @spy = spy_ = []

      default_play_class do
        define_attribute(:spy) { spy_ }
      end

      define_worker :test_worker, 2

      namespace :ns do
        play :parent do
          worker :test_worker

          param :date, type: :date

          def run
            spy << [:parent, date]
          end
        end

        task :rake_task do
          spy_ << [:rake_task]
        end
      end

      play :test do
        param :date, type: :date

        def setup
          needs 'ns:parent', date: date
          needs 'ns:parent', date: date + 1
          needs 'ns:rake_task'

          needs 'ns:parent', date: date
        end

        def run
          spy << [:child, date]
        end
      end
    end

    def test_invoke
      @spy.clear
      app.executor.invoke(app[:test, nil, date: '2016-01-01'])

      parents_result = @spy.select { |n, _| n == :parent }.sort_by(&:last)
      assert_equal [:parent, Date.new(2016, 1, 1)], parents_result[0]
      assert_equal [:parent, Date.new(2016, 1, 2)], parents_result[1]
      assert_equal 2, parents_result.length

      assert_equal [:child, Date.new(2016, 1, 1)], @spy.last
      assert_includes @spy, [:rake_task]
    end
  end
end
