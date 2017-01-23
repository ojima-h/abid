require 'abid/cli/table_formatter'

module Abid
  class CLI
    class List
      def initialize(env, options, prefix)
        @env = env
        @options = options
        @prefix = prefix

        @after = Time.parse(options[:after]) if options[:after]
        @before = Time.parse(options[:before]) if options[:before]
      end

      def run
        puts build_table
      end

      def build_table
        states = @env.state_manager.states
                     .filter_by_prefix(@prefix)
                     .filter_by_start_time(after: @after, before: @before)
        table = states.map { |state| format_state(state) }
        TableFormatter.new(table).format
      end

      def format_state(state)
        t = state.start_time.strftime('%Y-%m-%d %H:%M:%S') if state.start_time
        [
          state.id,
          t,
          state.state_label,
          format_exec_time(state.exec_time),
          state.name + ' ' + ParamsFormat.format(YAML.load(state.params))
        ]
      end

      def format_exec_time(exec_time)
        return '' unless exec_time

        if exec_time >= 60 * 60 * 24
          exec_time.div(60 * 60 * 24).to_s + ' days'
        else
          Time.at(exec_time).utc.strftime('%H:%M:%S').to_s
        end
      end
    end
  end
end
