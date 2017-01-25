require 'logger'
require 'abid/dsl/abid_task_instance'
require 'abid/dsl/actions'
require 'abid/dsl/mixin'
require 'abid/dsl/params_spec'
require 'abid/dsl/play_core'
require 'abid/dsl/play'
require 'abid/dsl/rake_task_instance'
require 'abid/dsl/syntax'
require 'abid/dsl/task_instance'
require 'abid/dsl/task_manager'
require 'abid/dsl/task'

module Abid
  class Application < Rake::Application
    def initialize(env)
      super()
      @rakefiles = %w(abidfile Abidfile abidfile.rb Abidfile.rb)
      @env = env
      @global_params = {}
      @global_mixin = DSL::Mixin.create_global_mixin
      @abid_task_manager = DSL::TaskManager.new(self)
      @after_all_actions = []
    end
    attr_reader :global_params, :global_mixin, :abid_task_manager,
                :after_all_actions
    alias abid_tasks abid_task_manager

    def init
      super
      @env.config.load(options.config_file)
    end

    def top_level
      super

      display_jobs_summary
    end

    def run_with_threads
      yield
    rescue Exception => err
      @env.engine.kill(err)
      raise err
    else
      @env.engine.shutdown
    end

    def invoke_task(task_string) # :nodoc:
      name, args = parse_task_string(task_string)
      @env.engine.invoke(name, {}, args)
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
           proc { options.wait_external_task = true }],
          ['--log-level LEVEL',
           'Specifies the log level. LEVEL can be error, warn, info or debug.' \
           ' (default: info)',
           proc do |v|
             options.log_level = Logger::Severity.const_get(v.upcase)
           end],
          ['--[no-]logging',
           'Enable logging. (default: on)',
           proc { |v| options.logging = v }],
          ['--[no-]summary',
           'Display jobs summary. (default: on)',
           proc { |v| options.summary = v }]
        ]
      )
    end

    def handle_options
      options.rakelib = %w(rakelib tasks)
      options.trace_output = $stderr
      options.log_level = Logger::Severity::INFO
      options.logging = true
      options.summary = true

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

    #
    # Abid Extentions
    #
    def logger
      return @logger if @logger
      logdev = options.logging ? $stderr : nil
      @logger = Logger.new(logdev).tap do |l|
        l.progname = 'abid'
        l.level = options.log_level || Logger::Severity::INFO
      end
    end
    attr_writer :logger

    def display_jobs_summary
      return if !options.summary || options.dryrun || options.preview
      return if @env.engine.summary.empty?
      puts "Summary:\n"
      @env.engine.pretty_summary.lines.each do |line|
        puts '  ' + line
      end
    end
  end
end
