require 'test_helper'

module Abid
  class PlayTest < AbidTest
    class SamplePlay < Abid::Play
      attr_accessor :callback_called
      set(:spy) { [] }
      set :worker, :dummy_worker

      param :date, type: :date
      param :dummy, type: :string, significant: false

      setup do
        needs :parent, date: date + 1
      end

      def run
        @spy = [worker, date, dummy]
      end

      around do |p|
        self.callback_called = true
        p.call
      end
    end

    def setup
      @task = Abid::Task.new('sample', app)
      SamplePlay.helpers do
        def sample_helper
          :sample
        end
      end
      SamplePlay.task = @task
    end

    def test_definition
      play = SamplePlay.new(date: '2000-01-01', dummy: 'foo')
      play._setup
      play._run

      assert_empty Abid::Play.params_spec
      assert_equal :dummy_worker, play.spy[0]
      assert_equal Date.new(2000, 1, 1), play.spy[1]
      assert_equal 'foo', play.spy[2]

      parent_name, parent_params = play.prerequisites.first
      assert_equal :parent, parent_name
      assert_equal Date.new(2000, 1, 2), parent_params[:date]

      assert play.callback_called
    end

    def test_equality
      play1 = SamplePlay.new(date: '2000-01-01', dummy: 'foo')
      play2 = SamplePlay.new(date: '2000-01-02', dummy: 'foo')
      play3 = SamplePlay.new(date: '2000-01-01', dummy: 'bar')

      assert !play1.eql?(play2)
      assert play1.eql?(play3)
    end

    def test_helper
      play = SamplePlay.new(date: '2000-01-01', dummy: 'foo')
      assert_equal :sample, play.sample_helper
    end
  end
end
