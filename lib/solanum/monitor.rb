# This file defines the Solanum::Monitor class.


module Solanum

# This class provides a top-level structure representing the monitoring
# configuration loaded with the Solanum::Lang module.
#
# Author:: Greg Look
class Monitor
    attr_reader :sources
    
    # Creates a new Monitor
    def initialize
        @sources = [ ]
    end
    
    # Collects recordings from each source and updates the given metrics
    def collect(metrics)
        raise "metrics must be provided" if metrics.nil?
        @sources.each {|source| source.collect(metrics) }
        metrics
    end
end

end
