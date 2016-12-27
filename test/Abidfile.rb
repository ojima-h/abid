play :test_ok do
  def run
    AbidTest.history << ['test_ok']
  end
end

play :test_ng do
  def run
    AbidTest.history << ['test_ng']
    raise 'ng'
  end
end

play :test_p1 do
  param :i, type: :int

  def run
    AbidTest.history << ['test_p1', i: i]
  end
end

play :test_p2 do
  param :i, type: :int
  setup { needs :test_p1 }

  def run
    AbidTest.history << ['test_p2', i: i]
  end
end

task :test_t1 do
  AbidTest.history << ['test_t1']
end

play :test_p3 do
  setup do
    needs :test_p2, i: 0
    needs :test_p2, i: 1
    needs :test_t1
  end

  def run
    AbidTest.history << ['test_p3']
  end
end

namespace :scheduler_test do
  # Cyclic Dependency
  play :c1 do
    setup { needs :c2 }
  end
  play :c2 do
    setup { needs :c3 }
  end
  play :c3 do
    setup { needs :c1 }
  end
end

namespace :test_args do
  task :t1, [:name, :age] => :t2 do |_, args|
    AbidTest.history << ['test_args:t1', name: args[:name], age: args[:age]]
  end

  task :t2, [:age] do |_, args|
    AbidTest.history << ['test_args:t2', age: args[:age]]
  end
end

define_worker :w1, 1
define_worker :w2, 1
namespace :test_worker do
  play :p1_1 do
    set :worker, :w1
    def run
      AbidTest.history << ['test_worker:p1_1', thread: Thread.current.object_id]
    end
  end

  play :p1_2 do
    set :worker, :w2
    def run
      AbidTest.history << ['test_worker:p1_2', thread: Thread.current.object_id]
    end
  end

  play :p1 do
    setup do
      needs :p1_1
      needs :p1_2
    end
  end
end
