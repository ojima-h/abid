module Abid
  class AbidErrorTaskAlreadyRunning < StandardError; end

  class State
    extend Forwardable
    extend MonitorMixin

    RUNNING = 1
    SUCCESSED = 2
    FAILED = 3

    STATES = constants.map { |c| [const_get(c), c] }.to_h

    @cache = {}
    class <<self
      def find(task)
        synchronize { @cache[task.object_id] ||= new(task) }
      end

      def list(pattern: nil, started_before: nil, started_after: nil)
        dataset = Rake.application.database[:states]

        dataset = dataset.where { start_time < started_before } if started_before
        dataset = dataset.where { start_time > started_after } if started_after
        dataset = dataset.order(:start_time)

        dataset.map do |record|
          next if pattern && record[:name] !~ pattern
          {
            id: record[:id],
            name: record[:name],
            params: deserialize(record[:params]),
            state: STATES[record[:state]],
            start_time: record[:start_time],
            end_time: record[:end_time]
          }
        end.compact
      end

      def serialize(params)
        YAML.dump(params)
      end

      def deserialize(bytes)
        YAML.load(bytes)
      end
    end

    def_delegators 'self.class', :serialize, :deserialize
    attr_reader :ivar

    def initialize(task)
      @task = task
      @record = nil
      @ivar = Concurrent::IVar.new
      @already_invoked = false
      reload
    end

    def only_once(&block)
      self.class.synchronize do
        return if @already_invoked
        @already_invoked = true
      end
      block.call
    end

    def database
      Rake.application.database
    end

    def dataset
      database[:states]
    end

    def disabled?
      @task.volatile? || Rake.application.options.disable_state
    end

    def preview?
      Rake.application.options.dryrun || Rake.application.options.preview
    end

    def reload
      return if disabled?

      if @record
        id = @record[:id]
        @record = dataset.where(id: id).first
      else
        @record = dataset.where(digest: digest).to_a.find do |r|
          [@task.name, @task.params].eql? [r[:name], deserialize(r[:params])]
        end
      end
    end

    def id
      @record[:id] if @record
    end

    def state
      @record[:state] if @record
    end

    def running?
      state == RUNNING
    end

    def successed?
      state == SUCCESSED
    end

    def failed?
      state == FAILED
    end

    def assume
      fail 'cannot revoke volatile task' if disabled?

      database.transaction do
        reload
        fail 'task is now running' if running?

        new_state = {
          state: SUCCESSED,
          start_time: Time.now,
          end_time: Time.now
        }

        if @record
          dataset.where(id: @record[:id]).update(new_state)
          @record = @record.merge(new_state)
        else
          id = dataset.insert(
            digest: digest,
            name: @task.name,
            params: serialize(@task.params),
            **new_state
          )
          @record = { id: id, **new_state }
        end
      end
    end

    def revoke
      fail 'cannot revoke volatile task' if disabled?

      database.transaction do
        reload
        fail 'task is not executed yet' if id.nil?
        fail 'task is now running' if running?
        dataset.where(id: id).delete
      end

      @record = nil
    end

    def session(&block)
      started = start_session
      block.call
    ensure
      close_session($ERROR_INFO) if started
    end

    def start_session
      return true if disabled? || preview?

      database.transaction do
        reload

        fail AbidErrorTaskAlreadyRunning if running?

        new_state = {
          state: RUNNING,
          start_time: Time.now,
          end_time: nil
        }

        if @record
          dataset.where(id: @record[:id]).update(new_state)
          @record = @record.merge(new_state)
        else
          id = dataset.insert(
            digest: digest,
            name: @task.name,
            params: serialize(@task.params),
            **new_state
          )
          @record = { id: id, **new_state }
        end

        true
      end
    end

    def close_session(error = nil)
      return if disabled? || preview?
      return unless @record
      state = error ? FAILED : SUCCESSED
      dataset.where(id: @record[:id]).update(state: state, end_time: Time.now)
      reload
    end

    def digest
      Digest::MD5.hexdigest(@task.name + "\n" + serialize(@task.params))
    end
  end
end
