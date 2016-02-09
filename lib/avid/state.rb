module Avid
  class State
    extend Forwardable

    RUNNING = 1
    SUCCESSED = 2
    FAILED = 3

    def self.find(task)
      new(task)
    end

    def initialize(task)
      @task = task
      reload
    end

    def database
      Rake.application.database
    end

    def dataset
      database[:states]
    end

    def volatile?
      !@task.is_a?(Avid::Task) || @task.volatile?
    end

    def reload
      return if volatile?

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

    def session
      if !volatile?
        begin
          start_session
          yield
        ensure
          close_session($ERROR_INFO)
        end
      else
        yield
      end
    end

    private

    def start_session
      database.transaction do
        reload

        fail 'task is now running' if running?

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
      end
    end

    def close_session(error = nil)
      return unless @record
      state = error ? FAILED : SUCCESSED
      dataset.where(id: @record[:id]).update(state: state, end_time: Time.now)
      reload
    end

    def digest
      Digest::MD5.hexdigest(@task.name + "\n" + serialize(@task.params))
    end

    def serialize(params)
      YAML.dump(params)
    end

    def deserialize(bytes)
      YAML.load(bytes)
    end
  end
end
