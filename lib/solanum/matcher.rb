# This class maps a line-matching pattern to a set of calculations on the
# matched data.
#
# Author:: Greg Look
class Solanum::Matcher
  attr_reader :pattern, :fn

  # Creates a new Matcher
  def initialize(pattern, &block)
    raise "pattern must be provided" if pattern.nil?
    raise "block must be provided" if block.nil?

    @pattern = pattern
    @fn = block
  end

  # Attempts to match the given line, calling it's recorder block with the
  # given match and metrics if matched. Returns a (potentially) updated
  # metrics map on match, or nil otherwise.
  def match(metrics, line)
    raise "line must be provided" if line.nil?
    raise "metrics must be provided" if metrics.nil?

    if @pattern === line
      @fn.call $~, metrics
      metrics
    end
  end

end
