module Abid
  class Config < Hash
    DEFAULT_SEARCH_PATH = [
      './config/abid.yml'
    ].freeze

    DEFAULT_DATABASE_CONFIG = {
      'adapter' => 'sqlite',
      'database' => './abid.db',
      'max_connections' => 1
    }.freeze

    # Config#load searches config file in `search_path` list.
    #
    # You can append an additinal config file path:
    #
    #     config.search_path.unshift('your_config_file')
    #
    # @return [Array<String>] search path
    attr_reader :search_path

    # @return [Hash] database configuration
    attr_reader :database

    def initialize
      super
      @database = {}
      @search_path = DEFAULT_SEARCH_PATH.dup
    end

    # Load config file.
    #
    # If `config_file` is specified and does not exist, it raises an error.
    #
    # If `config_file` is not specified, it searches config file in
    # `search_path`.
    #
    # When #load is called again, original cofnigurations is cleared.
    #
    # @param config_file [String] config file
    # @return [Config] self
    def load(config_file = nil)
      replace(load_config_file(config_file))
      @database = load_database_config
      self
    end

    private

    def load_config_file(file_path)
      return YAML.load_file(file_path) if file_path

      load_default_config_file
    rescue => e
      raise Error, 'failed to load config file: ' + e.message
    end

    def load_default_config_file
      file_path = search_path.find { |path| File.exist?(path) }
      return {} unless file_path
      YAML.load_file(file_path)
    end

    def load_database_config
      fetch('database') { DEFAULT_DATABASE_CONFIG.dup }
    end
  end
end
