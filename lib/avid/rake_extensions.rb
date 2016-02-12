module Avid
  module RakeExtensions
    require 'avid/rake_extensions/task'
    Rake::Task.include Task
  end
end
