# Defines the Solanum module and loads basic framework.

# Solanum namespace module.
# 
# Author:: Greg Look
module Solanum
end

require 'solanum/metrics'
require 'solanum/record'


class Solanum
    include Singleton
    
    attr_reader :metrics
    
    def initialize
        @metrics = { }
        @sources = [ ]
    end
    
    def record(path, value, options={})
        # get category path and metric name
        categories = path.split(/\./)
        metric = categories.pop
        
        # create category heirarchy
        pwc = []
        parent = @metrics
        categories.each do |name|
            pwc << name
            raise "Cannot create category in metric #{pwc.join('.')}" if parent[:values]
            parent[name] = { } unless parent[name]
            parent = parent[name]
        end
        
        # record metric
        pwc << metric
        raise "Cannot record metric in category #{pwc.join('.')}" if parent[metric] and not parent[metric][:values]
        parent[metric] ||= { :unit => options[:unit], :values = [ ] }
        parent[metric][:values] << { :time => Time.now, :value => value }
    end
    
    def run(command, &block)
        @sources << Source.new(:command, command)
        @sources.last.instance_eval block
    end
    
    def read(path, &block)
        @sources << Source.new(:file, path)
        @sources.last.instance_eval block
    end
    
    def collect_metrics
        # run source collection
    end
end


class Solanum::Source
    attr_reader :type, :source
    attr_reader :matchers
    
    def initialize(type, source)
        @type = type
        @source = source
        @matchers = [ ]
    end
    
    def match(pattern, options={}, &block)
        # ...
    end
    
end



