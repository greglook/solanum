# This file defines the Solanum::Metrics::Record class.

module Solanum
class Metrics

# This class represents a single recorded time/value pair.
#
# Author:: Greg Look
class Record
    attr_reader :time, :value, :unit
    
    # Creates a new Record
    def initialize(time, value, unit=nil)
        @time = time
        @value = value
        @unit = ( unit.is_a? Symbol ) && unit || unit.intern if unit
    end
end

end
end
