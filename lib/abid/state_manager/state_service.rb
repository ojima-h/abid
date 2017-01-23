require 'forwardable'

module Abid
  class StateManager
    # StateService updates the job status in a transaction.
    class StateService
      def initialize(model, name, params)
        @model = model
        @name = name
        @params = params
      end
      attr_reader :name, :params

      # @return [State] state
      def find
        cond = { name: name, params: params_text, digest: digest }
        @model.where(cond).first || @model.new(cond)
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

      private

      def transaction(&block)
        @model.db.transaction(
          isolation: :serializable,
          retry_on: Sequel::SerializationFailure,
          &block
        )
      end

      def params_text
        @params_text ||= YAML.dump(params.sort.to_h)
      end

      def digest
        @digest ||= Digest::MD5.hexdigest(name + "\n" + params_text)
      end
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
        @model.new(name: name, params: params_text, digest: digest)
      end
    end
  end
end
