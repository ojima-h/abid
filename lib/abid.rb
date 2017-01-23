require 'rake'
require 'date'
require 'digest/md5'
require 'English'
require 'forwardable'
require 'monitor'
require 'time'
require 'yaml'
require 'concurrent'
require 'rbtree'
require 'sqlite3'
require 'sequel'

require 'abid/application'
require 'abid/config'
require 'abid/environment'
require 'abid/error'
require 'abid/engine'
require 'abid/params_format'
require 'abid/rake_extensions'
require 'abid/state_manager'
require 'abid/version'

module Abid
  class << self
    def global
      @global ||= Environment.new
    end
    attr_writer :global

    def application
      global.application
    end
  end
end
