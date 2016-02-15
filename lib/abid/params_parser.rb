module Avid
  module ParamsParser
    class <<self
      def parse(params, specs)
        specs.map do |name, spec|
          if params.include?(name)
            value = type_cast(params[name], spec[:type])
          elsif ENV.include?(name.to_s)
            value = type_cast(ENV[name.to_s], spec[:type])
          elsif spec.key?(:default)
            value = spec[:default]
          else
            fail "param #{name} is not specified"
          end

          [name, value]
        end.to_h
      end

      def type_cast(value, type)
        case type
        when :boolean then value == 'true'
        when :int then value.to_i
        when :float then value.to_f
        when :string then value.to_s
        when :date then type_cast_date(value)
        when :datetime, :time then type_cast_time(value)
        when nil then value
        else fail "invalid type: #{type}"
        end
      end

      def type_cast_date(value)
        case value
        when Date then value
        when Time, DateTime then value.to_date
        else Date.parse(value.to_s)
        end
      end

      def type_cast_time(value)
        case value
        when Date then value.to_time
        when Time, DateTime then value
        else Time.parse(value.to_s)
        end
      end
    end
  end
end
