task default: :sample

desc "sample task"
play :sample do
  param :date, type: :date

  def setup
    needs "parents:sample", date: date - 1
  end

  def run
    puts "sample called with date=#{date}"
  end
end

namespace :parents do
  desc "sample parent task"
  play :sample do
    param :date, type: :date

    def run
      puts "parents:sample called with date=#{date}"
    end
  end
end
