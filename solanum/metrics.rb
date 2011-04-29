# This file defines the Solanum::Metrics class.


require 'solanum/metrics/category'
require 'solanum/metrics/record'


module Solanum

# This class provides a top-level collection of metric records, organized into
# a tree structure by categories.
#
# Author:: Greg Look
class Metrics
    attr_reader :root
    
    # Creates a new metrics collection
    def initialize
        @root = Category.new
    end
    
    # Records a new value in a metric's history
    def record(path, value, options={})
        return if value.nil?
        metric = resolve path
        metric.records << Record.new(Time.now, value, options[:unit])
    end
    
    # Measures a new value for a metric, but purges any history
    def measure(path, value, options={})
        return if value.nil?
        metric = resolve path
        metric.records.clear
        metric.records << Record.new(Time.now, value, options[:unit])
    end
    
    # Resolves a path to a metric, creating it if necessary
    def resolve(path)
        @root.resolve(path.strip.split('.').map {|p| p.intern })
    end
end

end
