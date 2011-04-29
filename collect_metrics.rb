#!/usr/bin/ruby
# Loads previous data and monitoring config and collects new records.


require 'solanum'


$monitor_file = ARGV.shift || "monitor.sol"
$data_file = ARGV.shift || "data.yml"

$monitor = Solanum.load_monitor($monitor_file)
$metrics = Solanum.load_metrics($data_file) || Solanum::Metrics.new

$monitor.collect $metrics

Solanum.save_metrics($metrics, $data_file)

Solanum.print_metrics $metrics.root
