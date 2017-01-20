module Abid
  module DSL
    # Actions manages action index of a play.
    #
    # It merges all actions of the play's ancestors.
    class Actions
      def initialize(play_class)
        @play_class = play_class
        @index = Hash.new { |h, k| h[k] = [] }
      end

      attr_reader :index
      protected :index

      # @param key [Symbol] action_name
      # @return [Enumerator<Proc>]
      def [](key)
        Enumerator.new do |y|
          # search key over including mixins
          @play_class.superplays.reverse.each do |sp|
            sp.actions.index[key].each { |block| y << block }
          end
        end
      end

      # @param key [Symbol] action name
      # @param scope [Rake::Scope] task scope where the action is declared
      # @param block [Proc] action body
      # @return self
      def add(key, scope, block)
        @index[key] << [scope, block]
        self
      end
    end
  end
end
