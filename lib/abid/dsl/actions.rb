module Abid
  module DSL
    class Actions
      def initialize(play_class)
        @play_class = play_class
        @hash = Hash.new { |h, k| h[k] = [] }
      end

      def _hash
        @hash
      end
      protected :_hash

      def [](key)
        Enumerator.new do |y|
          @play_class.superplays.reverse.each do |sp|
            sp.actions._hash[key].each { |block| y << block }
          end
        end
      end

      def add(key, scope, block)
        @hash[key] << [scope, block]
      end
    end
  end
end
