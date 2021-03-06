require 'test_helper'

module Abid
  class ParamsFormatTest < AbidTest
    def test_format
      params = {
        a: 1,
        b: 0.1,
        c: false,
        d: Date.new(2000, 1, 1),
        e: Time.new(2000, 1, 1, 12, 0, 0),
        f: 'some text'
      }
      str = ParamsFormat.format(params)

      assert_equal 'a=1 b=0.1 c=false d=2000-01-01 e=2000-01-01\\ 12:00:00 f=some\\ text', str
    end

    def test_format_error
      err = assert_raises Error do
        ParamsFormat.format(a: Object.new)
      end
      assert_match 'Object class is not supported', err.message
    end

    def test_parse_args
      args = [
        'task1', 'task2',
        'a=1', 'b=0.1', 'c=false', 'd=2000-01-01', 'e=2000-01-01 12:00:00',
        'f=some text', 'g=123abc???'
      ]
      params, tasks = ParamsFormat.collect_params(args)

      assert_equal %w(task1 task2), tasks
      assert_equal(
        {
          a: 1,
          b: 0.1,
          c: false,
          d: Date.new(2000, 1, 1),
          e: Time.new(2000, 1, 1, 12, 0, 0),
          f: 'some text',
          g: '123abc???'
        },
        params
      )
    end
  end
end
