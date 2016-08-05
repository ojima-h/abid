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

    def params_spec
      @params_spec ||= {}
    end

    def param(name, **param_spec)
      define_method(name) { task.params[name] }
      params_spec[name] = { significant: true }.merge(param_spec)
    end

    def undef_param(name)
      params_spec.delete(name)
      undef_method(name) if method_defined?(name)
    end

    def include(*mod)
      ms = mod.map do |m|
        if m.is_a? Module
          m
        else
          mixin_task = task.application[m, task.scope]

          fail "#{m} is not a mixin" unless mixin_task.is_a? MixinTask

          mixin_task.mixin.tap do |mixin|
            # inherit params_spec
            mixin.params_spec.each do |k, v|
              params_spec[k] ||= v
            end
          end
        end
      end

      super(*ms)
    end
  end
end
