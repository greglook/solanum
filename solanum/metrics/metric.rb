# This file defines the Solanum::Metrics::Metric class.

module Solanum
class Metrics

# This class represents a single metric with a latest value and a history.
#
# Author:: Greg Look
class Metric
    attr_reader :records
    
    # Creates a new Metric
    def initialize
        @records = [ ]
    end
end

end
end
