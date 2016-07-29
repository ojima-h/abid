module Abid
  module PlayCore
    def set(name, value = nil, &block)
      var = :"@#{name}"

      define_method(name) do
        unless instance_variable_defined?(var)
          if !value.nil?
            instance_variable_set(var, value)
          elsif block_given?
            instance_variable_set(var, instance_eval(&block))
          end
        end
        instance_variable_get(var)
      end
    end

    def include(*mod)
      ms = mod.map do |m|
        if m.is_a? Module
          m
        else
          mixin_task = task.application[m, task.scope]

          fail "#{m} is not a mixin" unless mixin_task.is_a? MixinTask

          mixin_task.mixin
        end
      end

      super(*ms)
    end
  end
end
