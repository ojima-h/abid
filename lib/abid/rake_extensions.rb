module Abid
  module RakeExtensions
    require 'abid/rake_extensions/task'
    Rake::Task.include Task
  end
end
