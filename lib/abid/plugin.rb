module Abid
  module Plugin
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
  end
end
