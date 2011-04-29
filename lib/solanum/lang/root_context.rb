# This file defines the Solanum::Lang::RootContext class.


require 'solanum/monitor/source'


module Solanum
module Lang

# This class provides the root context for the Solanum monitoring configuration
# DSL.
#
# Author:: Greg Look
class RootContext
    attr_reader :sources
    
    # Creates a new RootContext
    def initialize
        @sources = [ ]
    end
    
    # Creates a :command Source and configures it with the matchers defined in
    # the given block.
    def run(command, &block)
        source = Solanum::Monitor::Source.new(:command, command)
        
        context = InputContext.new(source)
        context.instance_exec &block
        
        @sources << source
    end
    
    # Creates a :file source and configures it with the matchers defined in
    # the given block.
    def read(path, &block)
        source = Solanum::Monitor::Source.new(:file, path)
        
        context = InputContext.new(source)
        context.instance_exec &block
        
        @sources << source
    end
    
    # Computes records directly.
    def compute(&block)
        source = Solanum::Monitor::Source.new(:compute, block)
    end
end

end
end
