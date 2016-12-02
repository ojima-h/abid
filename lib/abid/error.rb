module Abid
  class Error < StandardError; end

  class AlreadyRunningError < Error; end
  class StateNotFoundError < Error; end
end
