module Abid
  class CLI
    class Assume
      def initialize(env, options, args)
        @env = env
        @options = options
        @args = args

        @force = @options[:force]
      end

      def run
        params, tasks = ParamsFormat.collect_params(@args)

        tasks.each { |task| assume(task, params) }
      end

      def assume(task, params)
        signature = Signature.new(task, params)
        state = @env.state_manager.state(signature)
        state.assume(force: @force)

        s = state.find
        puts "#{signature} (id: #{s.id}) is assumed to be SUCCESSED."
      rescue AlreadyRunningError
        $stderr.puts "#{signature} already running.\n" \
                     'Use -f option if you want to force assume.'
        raise
      end
    end
  end
end
