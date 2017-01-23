require 'abid/cli/table_formatter'

module Abid
  class CLI
    class Revoke
      def initialize(env, options, job_ids)
        @env = env
        @options = options
        @job_ids = job_ids.map(&:to_i)

        @force = @options[:force]
        @quiet = @options[:quiet]
      end

      def run
        @job_ids.each do |job_id|
          state = @env.state_manager.states[job_id]
          if state.nil?
            $stderr.puts "#{job_id} is not found"
            next
          end

          text = ParamsFormat.format_with_name(state.name, state.params_hash)
          next if !@quiet && !ask(text)

          revoke(state, text)
        end
      end

      def revoke(state, text)
        state.revoke(force: @force)
        puts "revoked #{state.id}"
      rescue AlreadyRunningError
        $stderr.puts "#{text} already running.\n" \
                     'Use -f option if you want to force assume.'
      end

      def ask(text)
        print "revoke task \`#{text}'? "
        $stdout.flush
        ret = $stdin.gets
        ret.match(/y(es)?/i)
      end
    end
  end
end
