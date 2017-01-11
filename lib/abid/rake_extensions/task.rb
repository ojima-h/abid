module Abid
  module RakeExtensions
    module Task
      def volatile?
        true
      end

      def worker
        :default
      end

      def job
        Job[name, defined?(params) ? params : {}]
      end

      def params
        {}
      end

      def name_with_params
        name
      end

      def concerned?
        true
      end

      def top_level?
        application.top_level_tasks.any? { |t| application[t] == self }
      end

      def hooks
        @hooks ||= Hash.new { |h, k| h[k] = [] }
      end

      def call_hooks(tag, *args)
        hooks[tag].each { |h| h.call(*args) }
      end
    end
  end
end
