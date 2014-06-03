require 'solanum/config'
require 'solanum/source'


# Namespace module with some handy utility methods.
#
# Author:: Greg Look
module Solanum

  # Loads monitor scripts and returns an array of the loaded sources and
  # services.
  def self.load(scripts)
    sources = []
    services = []

    scripts.each do |path|
      begin
        #log "Loading monitor script #{path}"
        config = Solanum::Config.new(path)
        sources.concat(monitor.sources)
        services.concat(monitor.services)
      rescue => e
        STDERR.puts "Error loading monitor script #{path}: #{e}"
      end
    end

    return sources, services
  end


  # Collects metrics from the given sources, in order. Returns a merged map of
  # metric data.
  def self.collect(sources)
    sources.reduce({}) do |metrics, source|
      new_metrics = nil
      begin
        new_metrics = source.collect(metrics)
      rescue => e
        STDERR.puts "Error collecting metrics from #{source}: #{e}"
      end
      new_metrics || metrics
    end
  end

end
