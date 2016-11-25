module Abid
  module Common
    module Utils
      def self.symbolize_keys(hash)
        hash.map { |key, value| [key.to_sym, value] }.to_h
      end
    end
  end
end
