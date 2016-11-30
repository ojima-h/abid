require 'shellwords'

module Abid
  module ParamsFormat
    def self.normalize(params)
      params.sort.to_h.freeze
    end

    def self.dump(params)
      YAML.dump(normalize(params))
    end

    def self.load(string)
      YAML.load(string)
    end

    def self.signature(name, params)
      name + "\n" + dump(params)
    end

    def self.digest(name, params)
      Digest::MD5.hexdigest(signature(name, params))
    end

    def self.format(params)
      normalize(params).map do |key, value|
        val = Shellwords.escape(format_value(value))
        "#{key}=#{val}"
      end.join(' ')
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

    def self.parse_args(args)
      tasks = []
      params = {}

      args.each do |arg|
        m = arg.match(/^(\w+)=(.*)$/m)
        if m
          params.store(m[1].to_sym, parse_value(m[2]))
        else
          tasks << arg unless arg =~ /^-/
        end
      end

      [tasks, params]
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
      else
        value
      end
    end
  end
end
