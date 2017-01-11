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
        tasks, params = ParamsFormat.parse_args(@args)

        tasks.each { |task| assume(task, params) }
      end

      def assume(task, params)
        params_str = ParamsFormat.format(params)

        job = @env.job_manager[task, params]
        state = job.state.assume(force: @force)

        puts "#{task} #{params_str} (id: #{state.id})" \
             ' is assumed to be SUCCESSED.'
      rescue AlreadyRunningError
        $stderr.puts "#{task} #{params_str} already running.\n" \
                     'Use -f option if you want to force assume.'
        raise
      end
    end
  end
end
