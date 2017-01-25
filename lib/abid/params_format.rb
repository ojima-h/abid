require 'date'
require 'time'
require 'shellwords'

module Abid
  module ParamsFormat
    def self.format(params)
      return '' unless params.is_a? Hash
      params.map do |key, value|
        val = Shellwords.escape(format_value(value))
        "#{key}=#{val}"
      end.join(' ')
    end

    def self.format_with_name(name, params)
      name + ' ' + format(params)
    end

    def self.format_value(value)
      case value
      when Numeric, TrueClass, FalseClass
        value.to_s
      when Date
        value.strftime('%Y-%m-%d')
      when Time, DateTime
        value.strftime('%Y-%m-%d %H:%M:%S')
      when String
        value
      else
        raise Error, "#{value.class} class is not supported"
      end
    end

    def self.collect_params(args)
      args.each_with_object([{}, []]) do |arg, (params, extras)|
        key, val = parse_pair(arg)
        key.nil? ? extras << arg : params[key] = val
      end
    end

    def self.parse_pair(str)
      m = str.match(/^(\w+)=(.*)$/)
      return unless m
      [m[1].to_sym, parse_value(m[2])]
    end

    def self.parse_value(value)
      case value
      when 'true', 'false'
        value == 'true'
      when /\A\d+\z/
        value.to_i
      when /\A\d+\.\d+\z/
        value.to_f
      when /\A\d{4}-\d{2}-\d{2}\z/
        Date.parse(value)
      when /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}( \d{4})?\z/
        Time.parse(value)
      when /\A(["']).*\1\z/
        value[1..-2]
      else
        value
      end
    end

    SUPPORTED_TYPES = [
      Numeric, TrueClass, FalseClass, Date, Time, DateTime, String
    ].freeze

    def self.validate_params!(params)
      params.values.each do |value|
        valid = SUPPORTED_TYPES.any? { |t| value.is_a? t }
        raise Error, "#{value.class} class is not supported" unless valid
      end
      params
    end
  end
end
