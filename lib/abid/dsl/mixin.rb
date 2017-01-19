require 'abid/dsl/play_core'

module Abid
  module DSL
    # `mixin` definition is evaluated in Mixin module context.
    #
    #     mixin :foo do
    #       # this is evaluated in Mixin module context
    #     end
    #
    module Mixin
      def self.create(task)
        Module.new do
          include Mixin
          extend Mixin::ClassMethods
          include task.application.global_mixin
          extend helpers
          @task = task
        end
      end

      def self.create_global_mixin
        Module.new do
          include Mixin
          extend Mixin::ClassMethods
        end
      end

      include PlayCore

      module ClassMethods
        include PlayCore::ClassMethods

        def included(obj)
          return unless obj.is_a? PlayCore::ClassMethods
          merge_helpers(obj)
        end

        def merge_helpers(obj)
          my_helpers = helpers
          obj.helpers.module_eval { include my_helpers }
          obj.extend(obj.helpers) # re-extend by helpers
        end
      end
    end
  end
end
