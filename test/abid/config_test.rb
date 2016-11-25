require 'test_helper'

require 'tempfile'

module Abid
  class ConfigTest < AbidTest
    def setup
      @config1 = Tempfile.open('config_test')
      @config1.puts <<-YAML
database:
  adapter: mysql
  host: localhost
something_else: 1
      YAML
      @config1.close

      @config2 = Tempfile.open('config_test')
      @config2.puts <<-YAML
something_else: 1
      YAML
      @config2.close
    end

    def test_load
      config = Abid::Config.new
      config.load(@config1.path)

      assert_equal 1, config['something_else']
      assert_equal 'mysql', config.database['adapter']
    end

    def test_default_database_config
      config = Abid::Config.new
      config.load(@config2.path)

      assert_equal 1, config['something_else']
      assert_equal 'sqlite', config.database['adapter']
      assert_equal './abid.db', config.database['database']
    end
  end
end
