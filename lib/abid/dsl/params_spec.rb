module Abid
  module DSL
    class ParamsSpec
      include Enumerable

      def initialize(play_class)
        @play_class = play_class
        @hash = {}
      end

      def [](key)
        @play_class.superplays.each do |sp|
          h = sp.params_spec._hash
          return h[key] if h.include?(key)
        end
        nil
      end

      def []=(key, val)
        @hash[key] = val
      end

      def delete(key)
        val = self[key]
        @hash[key] = nil
        val
      end

      def each(&block)
        to_h.each(&block)
      end

      def to_h
        h = {}
        @play_class.superplays.reverse.each do |sp|
          h.update(sp.params_spec._hash)
        end
        h.reject { |_, v| v.nil? }
      end

      def _hash
        @hash
      end
      protected :_hash

      def inspect
        to_h.inspect
      end

      def to_s
        to_h.to_s
      end
    end
  end
end
