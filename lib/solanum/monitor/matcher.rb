# This file defines the Solanum::Monitor::Matcher class.


module Solanum
class Monitor

# This class maps a line-matching pattern to a set of calculations on the
# matched data.
#
# Author:: Greg Look
class Matcher
    attr_reader :pattern, :calc

    # Creates a new Matcher
    def initialize(pattern, &block)
        raise "pattern must be provided" if pattern.nil?
        raise "block must be provided" if block.nil?

        @pattern = pattern
        @calc = block
    end

    # Attempts to match the given line
    def match(line, metrics)
        raise "line must be provided" if line.nil?
        raise "metrics must be provided" if metrics.nil?

        if @pattern === line
            metrics.instance_exec $~, &@calc
            true
        else
            false
        end
    end
end

end
end
