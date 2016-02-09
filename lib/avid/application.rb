module Avid
  class Application < Rake::Application
    include Avid::TaskManager

    attr_reader :executor
    attr_reader :config

    def initialize
      super
      @rakefiles = %w(avidfile Avidfile avidfile.rb Avidfile.rb)
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

        @executor = TaskExecutor.new(self)
      end
    end

    def run_with_threads
      yield
    ensure
      executor.shutdown
    end

    def invoke_task(task_string) # :nodoc:
      name, args = parse_task_string(task_string)
      t = self[name]
      executor.invoke(t, *args)
    end

    def default_config
      {
        'avid' => {
          'database_url' => 'sqlite://' + File.join(Dir.pwd, 'avid.db')
        }
      }
    end

    def sort_options(options)
      super.push(version)
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
        opts.separator '    bundle exec avid [--dry-run] TASK'
        opts.separator ''
        opts.separator 'Advanced options:'

        opts.on_tail('-h', '--help', '-H', 'Display this help message.') do
          puts opts
          exit
        end

        standard_rake_options.each { |args| opts.on(*args) }
        opts.environment('RAKEOPT')
      end.parse!
    end

    def database
      @database ||= Sequel.connect(config['avid']['database_url'])
    end

    private

    def version
      ['--version', '-V',
       'Display the program version.',
       lambda do |_value|
         puts "Avid Version: #{Avid::VERSION} (Rake Version: #{RAKEVERSION})"
         exit
       end
      ]
    end

    def load_rakefile
      super
      standard_exception_handling do
        Rake.load_rakefile(File.expand_path('../../Avidfile.rb', __FILE__))
      end
    end
  end
end
