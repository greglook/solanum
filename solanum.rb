#!/usr/bin/ruby
# Loads previous data and monitoring config and collects new records.


require 'solanum/lang'
require 'solanum/metrics'
require 'solanum/monitor'
require 'yaml'


# Solanum namespace module.
module Solanum
    
    # Loads a monitoring file and builds a Monitor.
    def self.load_monitor(*files)
        context = Lang::RootContext.new
        files.each do |path|
            context.instance_eval File.readlines(path).join, path, 1
        end
        context.monitor
    end
    
    # Loads metrics records from the given file.
    def self.load_metrics(path)
        return nil unless File.exist? path
        
        File.open(path) {|file| YAML.load file }
    end
    
    # Saves metrics records to the given file.
    def self.save_metrics(metrics, path)
        File.open(path, 'w') {|file| file << metrics.to_yaml }
    end
    
    # Prints out metrics and current values, sorted by key.
    def self.print_metrics(metrics)
        metrics.metrics.keys.sort.each do |name|
            metric = metrics.metrics[name]
            
            values = metric.units.map {|u| "%s%s" % [metric.value(u), ( u == :'1' ) ? "" : (" " << u.to_s)] }
            
            puts "%s: %s" % [name, values.join(' / ')]
        end
    end
    
end


# if file is being executed directly, collect metrics
if $0 == __FILE__
    DATA_FILE = "/tmp/solanum_metrics.yml"
    
    # check arguments
    if ARGV.empty?
        puts "Usage: #{$0} <monitor script> [monitor script] ..."
        exit 1
    end
    
    monitor = Solanum.load_monitor *ARGV
    metrics = Solanum.load_metrics(DATA_FILE) || Solanum::Metrics.new
    
    monitor.collect metrics
    
    Solanum.save_metrics metrics, DATA_FILE
    
    Solanum.print_metrics metrics
end
