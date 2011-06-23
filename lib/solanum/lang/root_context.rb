# This file defines the Solanum::Lang::RootContext class.


require 'solanum/lang/input_context'
require 'solanum/monitor'
require 'solanum/monitor/source'


module Solanum
module Lang

# This class provides the root context for the Solanum monitoring configuration
# DSL.
#
# Author:: Greg Look
class RootContext
  attr_reader :monitor
  
  # Creates a new RootContext
  def initialize
    @monitor = Solanum::Monitor.new
  end
  
  # Sets the location of a persisted data file to use.
  def data_file(path)
    @monitor.data_file = path
  end
  
  # Allows definition of helper methods to be run inside the metrics class.
  def metrics_helpers(&block)
    @monitor.sources << Solanum::Monitor::Source.new(:compute, block)
  end
  
  # Allows definition of helper methods to be available inside input contexts.
  def input_helpers(&block)
    Solanum::Lang::InputContext.class_eval &block
  end
  
  # Creates a :command Source and configures it with the matchers defined in
  # the given block.
  def run(command, &block)
    source = Solanum::Monitor::Source.new(:command, command)
    
    context = InputContext.new(source)
    context.instance_exec &block
    
    @monitor.sources << source
  end
  
  # Creates a :file source and configures it with the matchers defined in
  # the given block.
  def read(path, &block)
    source = Solanum::Monitor::Source.new(:file, path)
    
    context = InputContext.new(source)
    context.instance_exec &block
    
    @monitor.sources << source
  end
  
  # Computes records directly.
  def compute(&block)
    @monitor.sources << Solanum::Monitor::Source.new(:compute, block)
  end
end

end
end
