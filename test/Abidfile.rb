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
