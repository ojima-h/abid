module Abid
  module DSL
    # ParamsSpec manages params specifications declared in a play definition.
    #
    # Ancestors' params_spec are inherited.
    class ParamsSpec
      include Enumerable

      attr_reader :specs
      protected :specs

      def initialize(play_class)
        @play_class = play_class
        @specs = {}
      end

      # @param key [Symbol] param name
      # @return [Hash] param specification
      def [](key)
        @play_class.superplays.each do |sp|
          h = sp.params_spec.specs
          return h[key] if h.include?(key)
        end
        nil
      end

      # @param key [Symbol] param name
      # @param val [Hash] param specification
      def []=(key, val)
        @specs[key] = val
      end

      # Mark given param as deleted.
      # It does not affect ancestors' params_spec.
      # @param key [Symbol] param name
      def delete(key)
        val = self[key]
        @specs[key] = nil
        val
      end

      # @yield [key, val] param name and spec
      def each(&block)
        to_h.each(&block)
      end

      def to_h
        h = {}
        @play_class.superplays.reverse.each do |sp|
          h.update(sp.params_spec.specs)
        end
        h.reject { |_, v| v.nil? }
      end

      def inspect
        to_h.inspect
      end

      def to_s
        to_h.to_s
      end
    end
  end
end
