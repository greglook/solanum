require 'solanum/source'


# Namespace module with some handy utility methods.
#
# Author:: Greg Look
module Solanum

  # Collects metrics from the given sources, in order. Returns a merged map of
  # metric data.
  def self.collect(sources)
    sources.reduce({}) do |metrics, source|
      new_metrics = nil
      begin
        new_metrics = source.collect(metrics)
      rescue => e
        STDERR.puts "Error collecting metrics from #{source}: #{e}"
        raise e
      end
      new_metrics || metrics
    end
  end

end
