require 'abid/dsl/play_core'

module Abid
  module DSL
    # `play` definition is evaluated in Play class context.
    #
    #     play :foo do
    #       # this is evaluated in Play class context
    #     end
    #
    class Play
      def self.create(task)
        Class.new(self) do
          include task.application.global_mixin
          extend helpers
          self.task = task
        end
      end

      include PlayCore
      extend PlayCore::ClassMethods

      def initialize(params)
        @params = params
        @prerequisite_tasks = []
      end

      # default settings
      set :worker,    :default
      set :volatile,  false
      set :concerned, true
      set :needed,    true
    end
  end
end
