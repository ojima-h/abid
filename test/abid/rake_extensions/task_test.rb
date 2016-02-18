require 'test_helper'

module Abid
  module RakeExtensions
    class TaskTest < AbidTest
      include Rake::DSL
      include Abid::DSL

      def setup
        @spy = spy_ = []

        play_base do
          set(:spy, spy_)
        end

        define_worker :test_worker, 2

        namespace :ns do
          play :root do
            param :date, type: :date

            def run
              spy << [:root, date]
            end
          end

          play :parent do
            set :worker, :test_worker

            param :date, type: :date

            setup do
              needs :root, date: date
            end

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

          setup do
            needs 'ns:parent', date: date
            needs 'ns:parent', date: date + 1
            needs 'ns:rake_task'

            needs 'ns:parent', date: date
          end

          def run
            spy << [:child, date]
          end
        end

        play :failure_play do
          def run
            fail Exception, 'test'
          end
        end

        task :failure_task do
          fail Exception, 'test'
        end
      end

      def test_invoke
        @spy.clear
        app[:test, nil, date: '2016-01-01'].async_invoke.wait!

        parents_result = @spy.select { |n, _| n == :parent }.sort_by(&:last)
        assert_equal [:parent, Date.new(2016, 1, 1)], parents_result[0]
        assert_equal [:parent, Date.new(2016, 1, 2)], parents_result[1]
        assert_equal 2, parents_result.length

        assert_equal [:child, Date.new(2016, 1, 1)], @spy.last
        assert_includes @spy, [:rake_task]
      end

      def test_check_prerequisites
        @spy.clear
        app[:test, nil, date: '2016-01-01'].async_invoke.wait!
        assert_equal 6, @spy.length

        State.find(app['ns:root', nil, date: '2016-01-02']).revoke

        @spy.clear
        app.instance_eval { @futures = {} }

        app.options.check_prerequisites = true
        app[:test, nil, date: '2016-01-01'].async_invoke.wait!
        assert_equal 3, @spy.length

        root_result = @spy.select { |n, _| n == :root }
        assert_equal 1, root_result.length
        assert_equal [:root, Date.new(2016, 1, 2)], root_result.first
      ensure
        app.options.check_prerequisites = false
      end

      def test_external_task_waiting
        app.options.wait_external_task = true
        app.options.wait_external_task_interval = 0.1

        task = app['test', nil, date: '2016-02-01']
        state = State.find(task)
        state.instance_eval { start_session }

        future = task.async_invoke

        sleep 0.1
        assert future.incomplete?

        state.dataset.where(id: state.id).update(state: State::SUCCESSED)
        sleep 0.1
        assert future.complete?
      ensure
        app.options.wait_external_task = false
      end

      def test_failure
        future = app['failure_play'].async_invoke
        assert_raises(Exception, 'test') { future.value! }

        future = app['failure_task'].async_invoke
        assert_raises(Exception, 'test') { future.value! }
      end
    end
  end
end
