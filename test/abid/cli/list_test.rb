require 'test_helper'
require 'abid/cli/list'

module Abid
  class CLI
    class ListTest < AbidTest
      def test_build_table
        states = Array.new(10) do |i|
          mock_state("job#{i % 2}:foo#{i}", i: i) do |s|
            s.start_time = Time.new(2000, 1, 1, i)
            s.end_time = Time.new(2000, 1, 1, i + 1)
          end
        end

        command = List.new(
          env,
          { after: '2000-01-01 03:00:00', before: '2000-01-01 06:00:00' },
          'job0:'
        )
        table = command.build_table

        expected = TableFormatter.new(
          [
            [states[4].id, '2000-01-01 04:00:00', 'SUCCESSED', '01:00:00', 'job0:foo4 i=4'],
            [states[6].id, '2000-01-01 06:00:00', 'SUCCESSED', '01:00:00', 'job0:foo6 i=6']
          ]
        ).format

        assert_equal expected, table
      end
    end
  end
end
