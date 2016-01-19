module Avid
  class Application < Rake::Application
    def initialize
      super
      @rakefiles = %w(avidfile Avidfile avidfile.rb Avidfile.rb) << avidfile
    end

    def name
      'avid'
    end

    def dry_run?
      @dry_run
    end

    def run
      Rake.application = self
      super
    end

    def sort_options(options)
      super.push(version, dry_run)
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

    private

    # allows the `avid install` task to load without a avidfile
    def avidfile
      File.expand_path(File.join(File.dirname(__FILE__), '..', 'Avidfile'))
    end

    def version
      ['--version', '-V',
       'Display the program version.',
       lambda do |_value|
         puts "Avid Version: #{Avid::VERSION} (Rake Version: #{RAKEVERSION})"
         exit
       end
      ]
    end

    def dry_run
      ['--dry-run', '-n',
       'Do a dry run without executing actions',
       -> (_value) { @dry_run = true }
      ]
    end
  end
end
