module Abid
  module ConcurrentExtention
    module IVar
      def try_fail(reason = StandardError.new)
        self.fail(reason)
        true
      rescue Concurrent::MultipleAssignmentError
        false
      end
    end
  end
end
