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
        sources.concat(config.sources)
        services.concat(config.services)
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


  # Build full events from a set of service prototypes, old metrics, and new
  # metrics.
  def self.build(services, old_metrics, new_metrics, defaults={})
    new_metrics.keys.sort.map do |service|
      value = new_metrics[service]
      prototype = services.select{|m| m[0] === service }.map{|m| m[1] }.reduce({}, &:merge)
      state = prototype[:state] ? prototype[:state].call(value) : :ok
      tags = ((prototype[:tags] || []) + (defaults[:tags] || [])).uniq
      ttl = prototype[:ttl] || defaults[:ttl]

      if prototype[:diff]
        last = old_metrics[service]
        if last && last <= value
          value = value - last
        else
          value = nil
        end
      end

      if value
        {
          service: service,
          metric: value,
          state: state.to_s,
          tags: tags,
          ttl: ttl
        }
      end
    end.compact
  end

end
