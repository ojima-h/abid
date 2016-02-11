require 'rake'
require 'date'
require 'digest/md5'
require 'english'
require 'forwardable'
require 'time'
require 'yaml'
require 'concurrent'
require 'inifile'
require 'rbtree'
require 'sqlite3'
require 'sequel'

require 'avid/version'
require 'avid/waiter'
require 'avid/worker'
require 'avid/params_parser'
require 'avid/play'
require 'avid/state'
require 'avid/task'
require 'avid/task_manager'
require 'avid/task_executor'
require 'avid/dsl_definition'
require 'avid/application'

module Avid
  FIXNUM_MAX = (2**(0.size * 8 - 2) - 1) # :nodoc:
end
