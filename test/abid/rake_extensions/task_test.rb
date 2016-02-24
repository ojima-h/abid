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

        play :parent_failure do
          setup { needs :failure_play }
        end

        task :failure_task do
          fail Exception, 'test'
        end

        play :wrong_worker do
          set :worker, :dummy
          setup { needs 'ns:parent', date: Date.today }
        end
      end

      def clear
        @spy.clear
        State.instance_eval { @cache.clear }
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

      def test_repair
        @spy.clear
        app[:test, nil, date: '2016-01-01'].async_invoke.wait!
        assert_equal 6, @spy.length

        State.find(app['ns:root', nil, date: '2016-01-02']).revoke

        @spy.clear
        State.instance_eval { @cache.clear }

        app.options.repair = true
        app[:test, nil, date: '2016-01-01'].async_invoke.wait!
        assert_equal 4, @spy.length

        root_result = @spy.select { |n, _| n == :root }
        assert_equal 1, root_result.length
        assert_equal [:root, Date.new(2016, 1, 2)], root_result.first
      ensure
        app.options.repair = false
      end

      def test_repair_failure
        clear

        t = app['ns:root', nil, date: '2016-01-01']
        t.state.start_session
        t.state.close_session(StandardError.new)

        result = app[:test, nil, date: '2016-01-01'].async_invoke.wait
        assert result.rejected?
        assert_equal '1 prerequisites failed', result.reason.message

        i = app['ns:parent', nil, date: '2016-01-01'].state.ivar
        assert i.rejected?
        assert_equal 'prerequisites have been failed', i.reason.message

        clear
        app.options.repair = true

        result = app[:test, nil, date: '2016-01-01'].async_invoke.wait
        assert result.fulfilled?
        assert_equal 4, @spy.count
      ensure
        app.options.repair = false
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

      def test_parent_failure
        f = app[:parent_failure].async_invoke.wait
        assert f.rejected?
        assert_kind_of StandardError, f.reason
        assert_equal '1 prerequisites failed', f.reason.message
      end

      def test_wrong_worker
        f = app[:wrong_worker].async_invoke.wait
        assert f.rejected?
        assert_equal 'worker dummy is not defined', f.reason.to_s
      end
    end
  end
end
