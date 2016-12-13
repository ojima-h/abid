require 'test_helper'

module Abid
  class JobTest < AbidTest
    def test_sort_params
      job = Job['name', b: 1, a: Date.new(2000, 1, 1)]

      assert_equal "---\n:a: 2000-01-01\n:b: 1\n", job.params_str
    end

    def test_digest
      job1 = Job['name', b: 1, a: Date.new(2000, 1, 1)]
      job2 = Job['name', b: 1, a: Date.parse('2000-01-01')]
      job3 = Job['name', b: 2, a: Date.new(2000, 1, 1)]

      assert_equal job1.digest, job2.digest
      refute_equal job1.digest, job3.digest
    end
  end
end
