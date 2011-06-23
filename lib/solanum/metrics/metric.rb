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
  def record(new_value, unit=nil)
    return unless value
    @values[value_key unit] = new_value
    @time = Time.now
  end
  
  # Records a new rate and updates the base value.
  def record_rate(rate_unit, new_value, unit=nil, scale=1.0)
    return unless new_value
    old_value = value(unit)
    if old_value
      dv = new_value - old_value
      dt = Time.now - @time
      rate = ( dt > 0 ) ? scale.to_f*dv/dt : nil
      record rate, rate_unit
    end
    record new_value, unit
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
