# This file defines the Solanum::Metrics::Category class.


require 'solanum/metrics/metric'


module Solanum
class Metrics

# This class represents a tree of heirarchical categories.
#
# Author:: Greg Look
class Category < Hash
    # Resolves the given path to an end metric, creating intervening
    # elements as needed.
    def resolve(path)
        raise "Cannot create metric with empty path" if path.empty?
        
        if path.length == 1
            metric = path.shift
            self[metric] ||= Metric.new
        else
            category = path.shift
            self[category] ||= Category.new
            self[category].resolve(path)
        end
    end
    
    # Allows method-style child dereferencing
    def method_missing(op, *args, &block)
        raise "No category element named #{op}" unless self[op]
        self[op]
    end
end

end
end
