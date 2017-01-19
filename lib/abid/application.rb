module Abid
  class Application < Rake::Application
    attr_reader :global_params
    attr_reader :global_mixin

    def initialize(env)
      super()
      @rakefiles = %w(abidfile Abidfile abidfile.rb Abidfile.rb)
      @env = env
      @global_params = {}
      @global_mixin = DSL::Mixin.create_global_mixin
    end

    def init
      super
      @env.config.load(options.config_file)
    end

    def run_with_threads
      yield
    rescue Exception => err
      Engine.kill(err)
      raise err
    else
      Engine.shutdown
    end

    def invoke_task(task_string) # :nodoc:
      name, args = parse_task_string(task_string)
      Job.find_by_task(self[name]).root.invoke(*args)
    end

    def standard_rake_options
      super.each do |opt|
        case opt.first
        when '--execute-print'
          # disable short option (-p)
          opt.delete_at(1)
        when '--version'
          opt[-1] = lambda do |_value|
            puts "Abid Version: #{Abid::VERSION} (Rake Version: #{RAKEVERSION})"
            exit
          end
        end
      end
    end

    def abid_options
      sort_options(
        [
          ['--config-file', '-C CONFIG_FILE',
           'Config file path',
           proc { |v| options.config_file = v }],
          ['--repair',
           'Run the task in repair mode.',
           proc { options.repair = true }],
          ['--preview', '-p',
           'Run tasks in preview mode.',
           proc { options.preview = true }],
          ['--wait-external-task',
           'Wait a task finished if it is running in externl process',
           proc { options.wait_external_task = true }]
        ]
      )
    end

    def handle_options
      options.rakelib = %w(rakelib tasks)
      options.trace_output = $stderr

      OptionParser.new do |opts|
        opts.banner = 'See full documentation at https://github.com/ojima-h/abid.'
        opts.separator ''
        opts.separator 'Show available tasks:'
        opts.separator '    bundle exec abid -T'
        opts.separator ''
        opts.separator 'Invoke (or simulate invoking) a task:'
        opts.separator '    bundle exec abid [--dry-run | --preview] TASK'
        opts.separator ''
        opts.separator 'Abid options:'
        abid_options.each { |args| opts.on(*args) }
        opts.separator ''
        opts.separator 'Advanced options:'
        standard_rake_options.each { |args| opts.on(*args) }

        opts.on_tail('-h', '--help', '-H', 'Display this help message.') do
          puts opts
          exit
        end

        opts.environment('RAKEOPT')
      end.parse!
    end

    def collect_command_line_tasks(args)
      params, = ParamsFormat.collect_params(args)
      @global_params.update(params)
      super
    end
  end
end
