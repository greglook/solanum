# Class which wraps up an active Solanum monitoring system into an object.
#
# Author:: Greg Look
class Solanum
  attr_reader :sources, :services, :metrics

  require 'solanum/config'
  require 'solanum/source'


  # Loads the given monitoring scripts and initializes the sources and service
  # definitions.
  def initialize(scripts)
    @sources = []
    @services = []
    @metrics = {}

    scripts.each do |path|
      begin
        config = Solanum::Config.new(path)
        @sources.concat(config.sources)
        @services.concat(config.services)
      rescue => e
        STDERR.puts "Error loading monitor script #{path}: #{e}"
      end
    end

    @sources.freeze
    @services.freeze
  end


  # Collects metrics from the given sources, in order. Updates the internal
  # merged map of metric data.
  def collect!
    @old_metrics = @metrics
    @metrics = @sources.reduce({}) do |metrics, source|
      begin
        new_metrics = source.collect(metrics) || {}
        metrics.merge(new_metrics)
      rescue => e
        STDERR.puts "Error collecting metrics from #{source}: #{e}"
        metrics
      end
    end
  end


  # Builds full events from a set of service prototypes, old metrics, and new
  # metrics.
  def build_events(defaults={})
    @metrics.keys.sort.map do |service|
      value = @metrics[service]
      prototype = @services.select{|m| m[0] === service }.map{|m| m[1] }.reduce({}, &:merge)

      state = prototype[:state] ? prototype[:state].call(value) : :ok
      tags = ((prototype[:tags] || []) + (defaults[:tags] || [])).uniq
      ttl = prototype[:ttl] || defaults[:ttl]

      if prototype[:diff]
        last = @old_metrics[service]
        if last && last <= value
          value = value - last
        else
          value = nil
        end
      end

      if value
        defaults.merge({
          service: service,
          metric: value,
          state: state.to_s,
          tags: tags,
          ttl: ttl
        })
      end
    end.compact
  end

end
