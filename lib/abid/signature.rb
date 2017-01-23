require 'digest/md5'
require 'forwardable'
require 'yaml'

module Abid
  # A signature identifies each job.
  class Signature
    extend Forwardable

    # @param name [String,Symbol]
    # @param params [Hash]
    def initialize(name, params)
      @name = name.to_s
      @params = params.dup.freeze
      @key = [@name, @params].freeze
    end
    attr_reader :name, :params
    def_delegators :@key, :hash, :eql?

    def params_text
      @params_text ||= YAML.dump(params.sort.to_h)
    end

    def digest
      @digest ||= Digest::MD5.hexdigest(name + "\n" + params_text)
    end

    def to_s
      @name + ' ' + ParamsFormat.format(@params)
    end
  end
end
