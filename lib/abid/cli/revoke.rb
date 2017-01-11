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
          state = @env.db.states[job_id]
          if state.nil?
            $stderr.puts "#{job_id} is not found"
            next
          end

          next if !@quiet && !ask(state)

          revoke(state)
        end
      end

      def revoke(state)
        @env.db.states.revoke(state.id, force: @force)
        puts "revoked #{state.id}"
      rescue AlreadyRunningError
        params = ParamsFormat.format(YAML.load(state.params))
        $stderr.puts "#{state.name} #{params} already running.\n" \
                     'Use -f option if you want to force assume.'
      end

      def ask(state)
        params = ParamsFormat.format(YAML.load(state.params))
        print "revoke task \`#{state.name} #{params}'? "
        $stdout.flush
        ret = $stdin.gets
        ret.match(/y(es)?/i)
      end
    end
  end
end