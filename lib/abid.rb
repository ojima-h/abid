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
require 'abid/engine/process'
require 'abid/engine/process_manager'
require 'abid/engine/executor'
require 'abid/engine/scheduler'
require 'abid/engine/worker_manager'
require 'abid/engine/waiter'
require 'abid/params_format'
require 'abid/state_manager'
require 'abid/job'
require 'abid/job_manager'

require 'abid/rake_extensions'
require 'abid/version'
require 'abid/params_parser'

require 'abid/dsl/abid_task_instance'
require 'abid/dsl/actions'
require 'abid/dsl/mixin'
require 'abid/dsl/params_spec'
require 'abid/dsl/play_core'
require 'abid/dsl/play'
require 'abid/dsl/rake_task_instance'
require 'abid/dsl/syntax'
require 'abid/dsl/task_instance'
require 'abid/dsl/task'

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
