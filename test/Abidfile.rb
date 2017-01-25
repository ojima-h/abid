define_worker :w1, 1
define_worker :w2, 1

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

namespace :test_exception do
  play :p1_1 do
    worker :w1
    action { sleep }
  end

  play :p1_2 do
    worker :w2
    action { raise Exception, 'test' }
  end

  play :p2 do
    setup do
      needs :p1_1
      needs :p1_2
    end
    action { AbidTest.history << ['test_exception:p2'] }
  end
end

namespace :test_worker do
  play :p1_1 do
    worker :w1
    def run
      AbidTest.history << ['test_worker:p1_1', thread: Thread.current.object_id]
    end
  end

  play :p1_2 do
    worker :w2
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

namespace :test_dsl do
  namespace :ns do
    task(:m1_1) { AbidTest.history << ['test_dsl:ns:m1_1'] }

    mixin :m1 do
      helpers do
        def set_sx(n, v)
          set :"s#{n}", v
        end
      end

      param :j
      setup { needs :m1_1 } # relative task name
    end

    mixin :m2_0 do
      helpers do
        def h1
          :m2_0
        end

        def h2
          :m2_0
        end
      end
      param :p1, default: 0
      param :p2, default: 1
      param :p3
      set :s1, :m2_0
      set :s2, :m2_0
      set :s3, :m2_0
      setup { AbidTest.history << ['test_dsl:ns:m2_0.setup'] }
      after { AbidTest.history << ['test_dsl:ns:m2_0.after'] }
    end

    mixin :m2_1 do
      helpers do
        def h1 # overwrite helper
          :m2_1
        end
      end
      param :p1, default: 1 # overwrite default value
      param :s3, default: 'm2_1' # overwrite setting by param
      set :s1, :m2_1 # overwrite settings
      setup { AbidTest.history << ['test_dsl:ns:m2_1.setup'] }
      after { AbidTest.history << ['test_dsl:ns:m2_1.after'] }

      include :m2_0
    end

    mixin :m2_2 do
      param :p2 # overwrite param by no default
      set :p3, -2 # overwrite param
      set :s2, -> { :m2_2 } # overwrite setting by proc
      setup { AbidTest.history << ['test_dsl:ns:m2_2.setup'] }
      after { AbidTest.history << ['test_dsl:ns:m2_2.after'] }

      include :m2_0
    end

    mixin :m3_1 do
      param :p1, default: :m3_1
      set :s1, :m3_1
    end

    mixin :m3_2 do
      param :p2, default: :m3_2
      set :s2, :m3_2
    end

    mixin :m5 do
      action { AbidTest.history << ['test_dsl:ns:m5'] }
    end
  end

  play p1: [:p1_1, :p1_2] do
    include 'ns:m1'

    param :i
    set :s1
    set :s2, 0
    set :s3, -> { i + 1 }
    set(:s4) { i + 2 }
    set_sx 5, -> { i + 3 }

    setup do
      needs :p1_3
      needs :p1_3, i: i + 1
    end

    after do
      AbidTest.history << ['test_dsl:p1.after']
    end

    def run
      AbidTest.history << ['test_dsl:p1', i]
    end
  end

  play :p1_1
  play :p1_2 do
    param :i
    def run
      AbidTest.history << ['test_dsl:p1_2', i]
    end
  end
  play :p1_3 do
    param :i
    def run
      AbidTest.history << ['test_dsl:p1_3', i]
    end
  end

  play :p2 do
    include 'ns:m2_1'
    include 'ns:m2_2'
  end

  play :p3 do
    include 'ns:m3_1'

    undef_param :p1
    undef_param :p2

    undef_param :s1

    param :p3
    set :s3
    undef_param :p3
    undef_param :s3

    include 'ns:m3_2'
  end

  play :p4 do
    def run
      raise 'test'
    end

    after do |error|
      AbidTest.history << ['test_dsl:p4.after', error]
    end
  end

  play :p5 do
    include 'ns:m5'
    action { AbidTest.history << ['test_dsl:p5'] }
  end

  play :test_preview do
    safe_action { AbidTest.history << ['test_dsl:test_preview'] }
  end

  play :test_preview2 do
    action { AbidTest.history << ['test_dsl:test_preview2'] }
  end

  play :test_preview3 do
    def run
      AbidTest.history << ['test_dsl:test_preview3']
    end
  end
end
