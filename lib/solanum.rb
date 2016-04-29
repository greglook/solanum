require 'solanum/config'


# Class which wraps up an active Solanum monitoring system into an object.
class Solanum
  attr_reader :sources, :default_attrs, :outputs

  # Loads the given configuration file and initializes sources.
  def initialize(config_path)
    config = File.open(config_path) {|f| YAML.load(f) }

    # Load default event attributes.
    @default_attrs = config['event-attributes'] || {}

    # Load output configuration, defaulting to a print output.
    output_configs = config['outputs'] || []
    output_configs << {'type' => 'print'} if output_configs.empty?

    # Construct outputs from config.
    @outputs = output_configs.map do |conf|
      Config.construct_type('output', conf['type'], conf)
    end
    @outputs.reject!(&:nil?)
    @outputs.freeze

    # Load default source arguments and configuration.
    source_defaults = config['source-defaults'] || {}
    source_configs = config['sources'] || []

    # Construct sources from config.
    @sources = source_configs.map do |conf|
      Config.construct_type('source', conf['type'], source_defaults.dup.merge(conf))
    end
    @sources.reject!(&:nil?)
    @sources.freeze
  end
end
