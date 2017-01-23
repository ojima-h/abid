require 'forwardable'

module Abid
  class StateManager
    # StateService updates the job status in a transaction.
    class StateService
      def initialize(model, signature)
        @model = model
        @signature = signature
      end

      # @return [State] state
      def find
        @model.find_or_init_by_signature(@signature)
      end

      # @see State#start
      def start
        transaction { find.start }
        self
      end

      # Try to update the state to started unless volatile.
      # @see State#start
      # @return [true,false] false if already running
      def try_start
        start
        true
      rescue AlreadyRunningError
        false
      end

      # @see State#finish
      def finish(error = nil)
        transaction { find.finish(error) }
        self
      end

      def assume(force: false)
        find.assume(force: force)
        self
      end

      def transaction(&block)
        @model.db.transaction(
          isolation: :serializable,
          retry_on: Sequel::SerializationFailure,
          &block
        )
      end
      private :transaction
    end

    # NullStateService does not update job status.
    class NullStateService < StateService
      def start
        self
      end

      def finish(_ = nil)
        self
      end

      def assume(_ = {})
        self
      end
    end

    # VolatileStateService never access to database.
    class VolatileStateService < NullStateService
      def find
        @model.init_by_signature(@signature).tap(&:freeze)
      end
    end
  end
end
