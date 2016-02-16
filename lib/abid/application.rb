module Abid
  class Application < Rake::Application
    include Abid::TaskManager

    attr_reader :worker
    attr_reader :config
    attr_reader :futures

    def initialize
      super
      @rakefiles = %w(abidfile Abidfile abidfile.rb Abidfile.rb) << abidfile
      @futures = {}
      @worker = Worker.new(self)
    end

    def run
      Rake.application = self
      super
    end

    def init(app_name = 'abid')
      standard_exception_handling do
        @config = IniFile.new(content: default_config)
        @config.merge!(IniFile.load('config/abid.cfg'))
      end

      super(app_name)
    end

    # allows the built-in tasks to load without a abidfile
    def abidfile
      File.expand_path(File.join(File.dirname(__FILE__), '..', 'Abidfile.rb'))
    end

    # load built-in tasks
    def load_rakefile
      standard_exception_handling do
        glob(File.expand_path('../tasks/*.rake', __FILE__)) do |name|
          Rake.load_rakefile name
        end
      end
      super
    end

    def run_with_threads
      yield
    ensure
      worker.shutdown
    end

    def invoke_task(task_string) # :nodoc:
      name, args = parse_task_string(task_string)
      self[name].async_invoke(*args).value!
    end

    def default_config
      {}
    end

    def default_database_config
      {
        adapter: 'sqlite',
        database: File.join(Dir.pwd, 'abid.db'),
        max_connections: 1
      }
    end

    def standard_rake_options
      super.each do |opt|
        case opt.first
        when '--execute-print'
          # disable short option
          opt.delete_at(1)
        when '--dry-run'
          h = opt.last
          opt[-1] = lambda do |value|
            h.call(value)
            options.disable_state = true
          end
        when '--version'
          opt[-1] = lambda do |_value|
            puts "Abid Version: #{Abid::VERSION} (Rake Version: #{RAKEVERSION})"
            exit
          end
        end
      end
    end

    def abid_options # :nodoc:
      sort_options(
        [
          ['--check-parents', '-c',
           'Run the task if the parents was updated.',
           proc { options.check_prerequisites = true }
          ],
          ['--preview', '-p',
           'Run tasks in preview mode.',
           proc do
             options.disable_state = true
             options.preview = true
           end
          ],
          ['--wait-external-task',
           'Wait a task finished if it is running in externl process',
           proc do
             options.wait_external_task_interval = true
           end
          ]
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

    def database
      return @database if @database
      if config.sections.include?('abid database')
        cfg = config['abid database'].map { |k, v| [k.to_sym, v] }.to_h
      else
        cfg = default_database_config
      end
      @database = Sequel.connect(**cfg)
    end
  end
end
