require 'test_helper'

module Abid
  class PlayTest < AbidTest
    include Rake::DSL
    include Abid::DSL

    def setup
      play :sample do
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

      play :child, extends: :sample do
        undef_param :dummy
      end

      app.options.preview = true
    end

    def test_definition
      task = app[:sample, date: '2000-01-01', dummy: 'foo']
      play = task.play
      task.execute

      assert_empty Abid::Play.params_spec
      assert_equal :dummy_worker, play.spy[0]
      assert_equal Date.new(2000, 1, 1), play.spy[1]
      assert_equal 'foo', play.spy[2]

      assert_equal true, play.preview?

      parent_name, parent_params = task.prerequisites.first
      assert_equal :parent, parent_name
      assert_equal Date.new(2000, 1, 2), parent_params[:date]

      assert play.callback_called
    end

    def test_undef_param
      pc1 = app.lookup_play_class(:child)
      refute pc1.method_defined?(:dummy)

      pc2 = app.lookup_play_class(:sample)
      assert pc2.method_defined?(:dummy)
    end
  end
end
