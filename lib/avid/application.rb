module Avid
  class Application < Rake::Application
    include Avid::TaskManager

    attr_reader :worker
    attr_reader :config
    attr_reader :futures

    def initialize
      super
      @rakefiles = %w(avidfile Avidfile avidfile.rb Avidfile.rb)
      @futures = {}
      @waiter = Waiter.new
      @worker = Worker.new(self)
    end

    def run
      Rake.application = self
      super
    end

    def init(app_name = 'avid')
      super(app_name)

      standard_exception_handling do
        @config = IniFile.new(content: default_config)
        @config.merge!(IniFile.load('config/avid.cfg'))
      end
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
        database: File.join(Dir.pwd, 'avid.db'),
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
            puts "Avid Version: #{Avid::VERSION} (Rake Version: #{RAKEVERSION})"
            exit
          end
        end
      end
    end

    def avid_options # :nodoc:
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
      options.rakelib = ['rakelib']
      options.trace_output = $stderr

      OptionParser.new do |opts|
        opts.banner = 'See full documentation at https://github.com/ojima-h/avid.'
        opts.separator ''
        opts.separator 'Show available tasks:'
        opts.separator '    bundle exec avid -T'
        opts.separator ''
        opts.separator 'Invoke (or simulate invoking) a task:'
        opts.separator '    bundle exec avid [--dry-run | --preview] TASK'
        opts.separator ''
        opts.separator 'Avid options:'
        avid_options.each { |args| opts.on(*args) }
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
      if config.sections.include?('avid database')
        cfg = config['avid database'].map { |k, v| [k.to_sym, v] }.to_h
      else
        cfg = default_database_config
      end
      @database = Sequel.connect(**cfg)
    end

    def wait(**kwargs, &block)
      @waiter.wait(**kwargs, &block)
    end

    private

    def load_rakefile
      super
      standard_exception_handling do
        Rake.load_rakefile(File.expand_path('../../Avidfile.rb', __FILE__))
      end
    end
  end
end
