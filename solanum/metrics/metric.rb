# This file defines the Solanum::Metrics::Metric class.

module Solanum
class Metrics

# This class represents a single metric with a timestamp and one or more
# unit=>value pairs.
#
# Author:: Greg Look
class Metric
    attr_reader :time
    
    # Creates a new Metric
    def initialize
        @values = Hash.new
        @time = Time.now
    end
    
    # Records a new value
    def record(value, unit=nil)
        @values[value_key unit] = value
        @time = Time.now
    end
    
    # Gets a value for the given unit
    def value(unit=nil)
        @values[value_key unit]
    end
    
    # Returns a list of units this metric has values for
    def units
        @values.keys
    end
    
    # Removes all value records
    def clear
        @values.clear
    end
    
    private
    
    # Fixes user-provided units
    def value_key(unit)
        unit ||= '1'  # default unit of :1
        unit = unit.intern unless unit.is_a? Symbol
        unit
    end
end

end
end
