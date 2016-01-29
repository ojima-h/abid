require 'test_helper'

module Avid
  class PlayTest < Minitest::Test
    class SamplePlay < Avid::Play
      play_name :sample_play

      worker :dummy_worker

      param :date, type: :date
      param :dummy, type: :string, significant: false

      def setup
        needs :parent, date: date + 1
      end

      def run
        [worker, date, dummy]
      end
    end

    def test_definition
      play = SamplePlay.new(date: '2000-01-01', dummy: 'foo')
      ret = play.run

      assert_empty Avid::Play.params_spec
      assert_equal :dummy_worker, ret[0]
      assert_equal Date.new(2000, 1, 1), ret[1]
      assert_equal 'foo', ret[2]

      parent_name, parent_params = play.prerequisites.first
      assert_equal :parent, parent_name
      assert_equal Date.new(2000, 1, 2), parent_params[:date]
    end

    def test_hash
      play1 = SamplePlay.new(date: '2000-01-01', dummy: 'foo')
      play2 = SamplePlay.new(date: '2000-01-02', dummy: 'foo')
      play3 = SamplePlay.new(date: '2000-01-01', dummy: 'bar')

      assert play1.hash != play2.hash
      assert_equal play1.hash, play3.hash
    end
  end
end
