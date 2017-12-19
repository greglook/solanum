require 'yaml'

class Solanum
module Config

  # Helper method to clear the type cache.
  def self.clear_type_cache!
    @@type_classes = {}
  end


  # Resolve a type based on a library path.
  def self.resolve_type(namespace, type, lib_path=nil, class_name=nil)
    @@type_classes ||= {}

    type_key = "#{namespace}:#{type}"
    return @@type_classes[type_key] if @@type_classes.include?(type_key)

    lib_path ||= type.include?('/') ? type : "solanum/#{namespace}/#{type}"
    if class_name
      cls_path = class_name.split('::')
    else
      cls_path = lib_path.split('/').map {|w| w.capitalize }
    end

    begin
      require lib_path
      cls = cls_path.inject(Object) do |mod, class_name|
        mod.const_get(class_name) if mod
      end
      STDERR.puts "Unable to resolve class #{cls_path.join('::')}" unless cls
      @@type_classes[type_key] = cls
    rescue LoadError => e
      STDERR.puts "Unable to load code for #{type_key} type: #{e}"
      @@type_classes[type_key] = nil
    end

    @@type_classes[type_key]
  end


  # Resolves a type config string and constructs a new instance of it. Memoizes
  # the results of loading the class in the `@@type_classes` field.
  def self.construct_type(namespace, type, args)
    cls = resolve_type(namespace, type, args['lib_path'], args['class'])
    if cls.nil?
      STDERR.puts "Skipping construction of failed #{namespace} type #{type}"
      nil
    else
      begin
        puts "#{cls}.new(#{args.inspect})" # DEBUG
        cls.new(args)
      rescue => e
        STDERR.puts "Error constructing #{namespace} type #{type}: #{args.inspect} #{e}"
        nil
      end
    end
  end


  # Load the given configuration file. Returns a map with initialized :sources
  # and :outputs.
  def self.load_file(path)
    config = File.open(path) {|f| YAML.load(f) }

    defaults = config['defaults'] || {}

    # Construct sources from config.
    source_configs = config['sources'] || []
    sources = source_configs.map do |conf|
      self.construct_type('source', conf['type'], conf)
    end
    sources.reject!(&:nil?)

    # Construct outputs from config.
    output_configs = config['outputs'] || []
    outputs = output_configs.map do |conf|
      self.construct_type('output', conf['type'], conf)
    end
    outputs.reject!(&:nil?)

    {
      defaults: defaults,
      sources: sources,
      outputs: outputs,
    }
  end

end
end
