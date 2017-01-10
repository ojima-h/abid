module Abid
  class Config < Hash
    DEFAULT_DATABASE_CONFIG = {
      'adapter' => 'sqlite',
      'database' => './abid.db',
      'max_connections' => 1
    }.freeze

    # Config#load searches config file in `search_path` list.
    #
    # You can append an additinal config file path:
    #
    #     Config.search_path.unshift('your_config_file')
    #
    # @return [Array<String>] search path
    def self.search_path
      @search_path ||= [
        './config/abid.yml'
      ]
    end

    # @return [Hash] database configuration
    def database
      self['database'].each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
    end

    # Load config file.
    #
    # If `config_file` is specified and does not exist, it raises an error.
    #
    # If `config_file` is not specified, it searches config file in
    # Config.search_path.
    #
    # When #load is called again, original configurations is cleared.
    #
    # @param config_file [String] config file
    # @return [Config] self
    def load(config_file = nil)
      replace(load_config_file(config_file))
      assign_default
      self
    end

    # @return [String] YAML string
    def to_yaml
      YAML.dump(to_h)
    end

    private

    def load_config_file(file_path)
      return YAML.load_file(file_path) if file_path

      load_default_config_file
    rescue => e
      raise Error, 'failed to load config file: ' + e.message
    end

    def load_default_config_file
      file_path = self.class.search_path.find { |path| File.exist?(path) }
      return {} unless file_path
      YAML.load_file(file_path)
    end

    def assign_default
      self['database'] ||= DEFAULT_DATABASE_CONFIG.dup
    end
  end
end
