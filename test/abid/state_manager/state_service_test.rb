require 'test_helper'

module Abid
  class StateManager
    class StateServiceTest < AbidTest
      def new_state_service(name, params)
        StateService.new(env.state_manager.states, name, params)
      end

      def test_params_text
        service = new_state_service('name', b: 1, a: Date.new(2000, 1, 1))

        assert_equal "---\n:a: 2000-01-01\n:b: 1\n", service.send(:params_text)
      end

      def test_digest
        service1 = new_state_service('name', b: 1, a: Date.new(2000, 1, 1))
        service2 = new_state_service('name', b: 1, a: Date.parse('2000-01-01'))
        service3 = new_state_service('name', b: 2, a: Date.new(2000, 1, 1))

        assert_equal service1.send(:digest), service2.send(:digest)
        refute_equal service1.send(:digest), service3.send(:digest)
      end
    end
  end
end
