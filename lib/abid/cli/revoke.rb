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

          signature = Signature.new(state.name, state.params_hash)
          next if !@quiet && !ask(signature)

          revoke(state, signature)
        end
      end

      def revoke(state, signature)
        state.revoke(force: @force)
        puts "revoked #{state.id}"
      rescue AlreadyRunningError
        $stderr.puts "#{signature} already running.\n" \
                     'Use -f option if you want to force assume.'
      end

      def ask(signature)
        print "revoke task \`#{signature}'? "
        $stdout.flush
        ret = $stdin.gets
        ret.match(/y(es)?/i)
      end
    end
  end
end
