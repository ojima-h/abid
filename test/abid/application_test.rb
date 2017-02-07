require 'test_helper'

module Abid
  class ApplicationTest < AbidTest
    include DSL::Syntax

    def test_top_level
      after_all_called = false
      after_all do
        after_all_called = true
      end

      env.application.top_level_tasks.replace(['test_ok'])
      env.application.top_level

      assert after_all_called
      assert @env.engine.process_manager.shutdown?
      assert_equal({ successed: 1 }, @env.engine.process_manager.summary)
    end
  end
end
