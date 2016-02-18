task default: :sample

play :console do
  set :volatile, true
  def run
    require 'pry'
    Pry.start(self)
  end
end

play_base do
  around do |blk|
    begin
      blk.call
    ensure
      puts "#{task.name} finished"
    end
  end
end

desc 'sample task'
play :sample do
  param :date, type: :date

  setup do
    needs 'parents:sample', date: date - 1
  end

  def run
    puts "sample called with date=#{date}"
  end
end

namespace :parents do
  desc 'sample parent task'
  play :sample do
    param :date, type: :date

    def run
      puts "parents:sample called with date=#{date}"
    end
  end
end

desc 'broken task'
play :failure do
  def run
    fail
  end
end

