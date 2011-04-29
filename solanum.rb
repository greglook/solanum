# Loads previous data and monitoring config and collects new records.


require 'solanum/lang'
require 'solanum/metrics'
require 'solanum/monitor'
require 'yaml'


# Solanum namespace module.
module Solanum
    
    # Loads a monitoring file and builds a Monitor.
    def self.load_monitor(path)
        context = Lang::RootContext.new
        context.instance_eval File.readlines(path).join, path, 1
        context.monitor
    end
    
    # Loads metrics records from the given file.
    def self.load_metrics(path)
        return nil unless File.exist? path
        
        metrics = Metrics.new
        hash = File.open(path) {|f| YAML.load f }
        
        queue = []
        hash.each {|k,v| queue << [metrics.root, k, v] }
        until queue.empty?
            node = queue.shift
            
            if node[2].kind_of? Array
                metric = Metrics::Metric.new
                node[2].each {|r| metric.records << Metrics::Record.new(Time.at(r['time']), r['value'], r['unit']) }
                node[0][node[1].intern] = metric
            elsif node[2].kind_of? Hash
                category = Metrics::Category.new
                node[2].each {|k,v| queue << [category, k, v] }
                node[0][node[1].intern] = category
            else
                raise "Unknown node type: #{node.inspect}"
            end
        end
        
        metrics
    end
    
    # Saves metrics records to the given file.
    def self.save_metrics(metrics, path)
        hash = { }
        queue = []
        metrics.root.each {|k,v| queue << [hash, k, v] }
        until queue.empty?
            node = queue.shift
            
            if node[2].kind_of? Metrics::Metric
                node[0][node[1].to_s] = node[2].records.map do |r|
                    rh = { 'time' => r.time.to_f, 'value' => r.value }
                    rh['unit'] = r.unit if r.unit
                    rh
                end
            elsif node[2].kind_of? Metrics::Category
                category = { }
                node[2].each {|k,v| queue << [category, k, v] }
                node[0][node[1].to_s] = category
            else
                raise "Unknown node type: #{node.inspect}"
            end
        end
        
        File.open(path, 'w') {|f| f << hash.to_yaml }
    end
    
end
