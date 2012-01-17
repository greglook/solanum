# This file defines the Solanum namespace module.


require 'solanum/lang'
require 'solanum/metrics'
require 'solanum/monitor'
require 'yaml'


# Namespace module with some handy utility methods.
#
# Author:: Greg Look
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
    return nil unless path && File.exist?(path)
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
