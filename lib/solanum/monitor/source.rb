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
    
    # Creates a new Source
    def initialize(type, value)
        raise "Unknown source type #{type}" unless [:command, :file, :compute].include? type
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
                lines = %x{#{@value}}.split("\n")
            elsif @type == :file
                File.open(@value) {|file| lines = file.readlines } if File.readable? @value
            end
            
            # parse input
            @matchers.each do |matcher|
                matched = lines.find {|line| matcher.match line, metrics }
                lines.delete_at lines.index matched if matched
            end
        end
    end
end

end
end
