module Abid
  module ConcurrentExtention
    require 'abid/concurrent_extention/ivar'
    Concurrent::IVar.include IVar
  end
end
