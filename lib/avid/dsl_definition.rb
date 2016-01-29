module Avid
  module DSL
    def play(*args, &block)
      Avid::Task.define_play(*args, &block)
    end
  end
end

extend Avid::DSL
