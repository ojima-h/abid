require 'test_helper'

require 'tempfile'

module Abid
  class ConfigTest < AbidTest
    def setup
      @config1 = Tempfile.open('config_test')
      @config1.puts <<-YAML
id: 1
database:
  adapter: mysql
  host: localhost
      YAML
      @config1.close

      @config2 = Tempfile.open('config_test')
      @config2.puts <<-YAML
id: 2
      YAML
      @config2.close
    end

    def test_load
      config = Abid::Config.new
      config.load(@config1.path)

      assert_equal 1, config['id']
      assert_equal 'mysql', config.database['adapter']
    end

    def test_default_database_config
      config = Abid::Config.new
      config.load(@config2.path)

      assert_equal 2, config['id']
      assert_equal 'sqlite', config.database['adapter']
      assert_equal './abid.db', config.database['database']
    end

    def test_search_path
      config = Abid::Config.new
      Config.search_path.unshift(@config1.path)
      config.load

      assert_equal 1, config['id']
    ensure
      Config.search_path.delete(@config1.path)
    end

    def test_load_error
      config = Abid::Config.new

      assert_raises(Abid::Error) do
        config.load('dummy')
      end
    end
  end
end
