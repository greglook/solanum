# This file defines the Solanum::Metrics class.


require 'solanum/metrics/metric'


module Solanum

# This class provides a top-level collection of metric records.
#
# Author:: Greg Look
class Metrics
    attr_reader :metrics
    
    # Creates a new metrics collection
    def initialize
        @metrics = Hash.new
    end
    
    # Returns a Metric object for the given name, creating one if it does not
    # already exist.
    def get_metric(name)
        raise "Invalid metric name: #{name}" unless name =~ /^\w[\w.]+\w$/
        return @metrics[name] if @metrics[name]
        
        descendents = @metrics.keys.select {|m| m[0..name.length] == name + '.' }
        raise "Cannot create new metric in category #{name}" unless descendents.empty?
        
        path = name.split('.')
        ancestors = (0..(path.length-2)).map {|i| path[0..i].join('.') }
        ancestor = ancestors.find {|a| @metrics[a] }
        raise "Cannot create new metric #{name} under existing metric #{ancestor}" if ancestor
        
        @metrics[name] ||= Metric.new
    end
    
    # Records a new value in a metric's history
    def record(name, value, unit=nil)
        get_metric(name).record value, unit
    end
end

end
