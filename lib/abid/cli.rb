require 'thor'

module Abid
  class CLI < Thor
    class_option :config_file, aliases: '-C', desc: 'config file path'

    def initialize(*args)
      super(*args)
      Abid.config.load(options[:config_file])
    end

    desc 'config', 'Show current config'
    def config
      puts Abid.config.to_yaml
    end

    desc 'migrate', 'Run database migration'
    def migrate
      require 'abid/cli/migrate'
      Migrate.new(options).run
    end

    desc 'assume TASK [TASKS..] [PARAMS]', 'Assume the job to be SUCCESSED'
    option :force, type: :boolean, aliases: '-f',
                   desc: 'set the state even if the job is running'
    def assume(task, *rest_args)
      require 'abid/cli/assume'
      Assume.new(options, [task, *rest_args]).run
    rescue AlreadyRunningError
      exit 1
    end
  end
end
