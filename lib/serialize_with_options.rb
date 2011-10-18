module SerializeWithOptions
  def self.extended(base)
    base.class_attribute :serialization_conf
    base.class_attribute :serialization_opts
  end

  def serialize_with_options(set = :default, &block)
    conf = self.serialization_conf || {}
    opts = self.serialization_opts || {}

    conf[set] = Config.new.instance_eval(&block)

    self.serialization_conf = conf
    self.serialization_opts = opts

    include InstanceMethods
  end

  def serialization_configuration(set)
    conf = self.serialization_conf
    conf &&= conf[set] || conf[:default]
    conf.try(:dup) || { :methods => nil, :only => nil, :except => nil }
  end

  def serialization_options(set)
    options = self.serialization_opts

    options[set] ||= serialization_configuration(set).tap do |opts|
      includes = opts.delete(:includes)

      if includes
        opts[:include] = includes.inject({}) do |hash, class_name|
          if class_name.is_a? Hash
            hash.merge(class_name)
          else
            begin
              klass = class_name.to_s.classify.constantize
              hash[class_name] = klass.serialization_configuration(set)
              hash[class_name][:include] = nil if hash[class_name].delete(:includes)
              hash
            rescue NameError
              hash.merge(class_name => { :include => nil })
            end
          end
        end
      end
    end

    self.serialization_opts = options
    options[set]
  end

  class Config
    undef_method :methods
    Instructions = [:skip_instruct, :dasherize, :skip_types, :root_in_json].freeze

    def initialize
      @data = { :methods => nil, :only => nil, :except => nil }
    end

    def method_missing(method, *args)
      @data[method] = Instructions.include?(method) ? args.first : args
      @data
    end
  end

  module InstanceMethods
    def to_xml(*args)
      set, opts = parse_serialization_options(*args)
      super(self.class.serialization_options(set).deep_merge(opts))
    end

    def to_json(*args)
      set, opts = parse_serialization_options(*args)
      super(self.class.serialization_options(set).deep_merge(opts))
    end

    private

    def parse_serialization_options(*args)
      if args.empty?
        set = :default
        opts = {}
      elsif (args.length == 1) && args[0].is_a?(Hash)
        set = :default
        opts = args.first
      elsif (args.length == 1) && args[0].is_a?(Symbol)
        set  = args.first
        opts = {}
      elsif (args.length == 2) && args[0].is_a?(Symbol) && args[1].is_a?(Hash)
        set  = args[0]
        opts = args[1]
      else
        raise ArgumentError, "Invalid arguments #{args.inspect}"
      end

      [set, opts]
    end
  end
end
