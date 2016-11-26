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
  end
end
