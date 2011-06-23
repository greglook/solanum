# This file defines the Solanum::Monitor::Source class.


module Solanum
class Monitor

# This class represents a source of data, whether read from command output,
# a file on the system, or just calculated from other values.
#
# Author:: Greg Look
class Source
  attr_reader :type, :value
  attr_reader :matchers
  
  TYPES = [:command, :file, :compute].freeze
  
  # Creates a new Source
  def initialize(type, value)
    raise "Unknown source type #{type}" unless TYPES.include? type
    @type = type
    @value = value
    @matchers = [ ]
  end
  
  # Collects recordings from matchers (or directly, for :compute)
  def collect(metrics)
    raise "metrics must be provided" if metrics.nil?
    
    if @type == :compute
      # compute metrics directly
      metrics.instance_exec &@value
    else
      lines = nil
      
      # collect input
      if @type == :command
        exe = @value.split(/\s/).first
        which = %x{which #{exe} 2> /dev/null} unless File.executable? exe
        if File.executable?(which || exe)
          lines = %x{#{@value}}.split("\n")
          puts "Error executing command: #{@value}" unless $?.success?
        else
          puts "Command #{exe} not found"
        end
      elsif @type == :file
        puts "File does not exist: #{@value}" unless File.exists? @value
        puts "File is not readable: #{@value}" unless File.readable? @value
        File.open(@value) {|file| lines = file.readlines } if File.readable? @value
      end
      
      # parse input
      lines && lines.each do |line|
        @matchers.detect {|m| m.match line, metrics }
      end
    end
  end
end

end
end
