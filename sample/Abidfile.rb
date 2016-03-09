require 'open-uri'

task default: 'count'

play :sample do
  set :volatile, true
  param :name, type: :string

  def run
    puts name
  end
end

play :fetch_source do
  param :date, type: :date

  def run
    open('http://example.com') do |f|
      FileUtils.makedirs "out/#{date.strftime('%Y-%m-%d')}"
      File.write("out/#{date.strftime('%Y-%m-%d')}/example.com", f.read)
    end
  end
end

play :count do
  param :date, type: :date

  setup do
    needs 'fetch_source', date: date
  end

  def run
    puts File.read("out/#{date.strftime('%Y-%m-%d')}/example.com").lines.length
  end
end

play :console do
  set :volatile, true
  def run
require 'pry'
    Pry.start(self)
  end
end
