module Abid
  class Error < StandardError; end

  class AlreadyRunningError < Error; end

  class NoParamError < NameError; end
end
