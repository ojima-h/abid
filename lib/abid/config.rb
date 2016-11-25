module Abid
  class Config < Hash
    DEFAULT_CONFIG_FILE = './config/abid.yml'.freeze
    DEFAULT_DATABASE_CONFIG = {
      adapter: 'sqlite',
      database: './abid.db',
      max_connections: 1
    }.freeze

    attr_reader :database

    def initialize
      super
      @database = {}
    end

    def load(config_file = nil)
      clear
      merge(load_config_file(config_file || DEFAULT_CONFIG_FILE))
      @database = load_database_config
      self
    end

    private

    def load_config_file(file_path)
      File.exist?(file_path) ? YAML.load_file(file_path) : {}
    end

    def load_database_config
      if key?('database')
        Common::Utils.symbolize_keys(fetch('database'))
      else
        DEFAULT_DATABASE_CONFIG.dup
      end
    end
  end
end
