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

require 'abid/config'
require 'abid/environment'
require 'abid/error'
require 'abid/engine'
require 'abid/params_format'
require 'abid/state_manager'

require 'abid/rake_extensions'
require 'abid/version'
require 'abid/params_parser'
require 'abid/application'

module Abid
  FIXNUM_MAX = (2**(0.size * 8 - 2) - 1) # :nodoc:

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
