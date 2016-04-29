require 'yaml'

class Solanum
module Config

  # Helper method to clear the type cache.
  def self.clear_type_cache!
    @@type_classes = {}
  end


  # Resolve a type based on a library path.
  def self.resolve_type(namespace, type)
    @@type_classes ||= {}

    type_key = "#{namespace}:#{type}"
    return @@type_classes[type_key] if @@type_classes.include?(type_key)

    lib_path = type.include?('/') ? type : "solanum/#{namespace}/#{type}"
    cls_path = lib_path.split('/').map{|w| w.capitalize }

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
    cls = resolve_type(namespace, type)
    if cls.nil?
      STDERR.puts "Skipping construction of failed #{namespace} type #{type}"
      nil
    else
      begin
        cls.new(args)
      rescue => e
        STDERR.puts "Error constructing #{namespace} type #{type}: #{args.inspect} #{e}"
        nil
      end
    end
  end

end
end
