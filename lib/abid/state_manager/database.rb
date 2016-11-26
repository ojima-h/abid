module Abid
  module StateManager
    module Database
      Sequel.extension :migration

      # Create a new database object.
      #
      # Abid.config['database'] is used Sequel.connect params.
      #
      # @return [Sequel::Database] database object
      def self.connect
        # symbolize keys
        params = {}
        Abid.config.database.each { |k, v| params[k.to_sym] = v }

        Sequel.connect(**params)
      end

      def self.migrations_path
        File.expand_path('../../../../migrations', __FILE__)
      end
    end
  end
end
