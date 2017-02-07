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
        state = @env.state_manager.state(task, params)
        state.assume(force: @force)

        s = state.find
        n = ParamsFormat.format_with_name(task, params)
        puts "#{n} (id: #{s.id}) is assumed to be SUCCESSED."
      rescue AlreadyRunningError
        $stderr.puts "#{n} already running.\n" \
                     'Use -f option if you want to force assume.'
        raise
      end
    end
  end
end
