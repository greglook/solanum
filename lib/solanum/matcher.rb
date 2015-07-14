# A matcher takes in a collection of lines and updates the given metrics
# hash by computing a function over the input.
#
# Author:: Greg Look
class Solanum::Matcher
  attr_reader :fn

  # Creates a new Matcher
  def initialize(fn)
    raise "function must be provided" if fn.nil?
    @fn = fn
  end

  # Attempts to match the given input, updating the metrics hash with
  # parsed data.
  def call(metrics, lines)
    metrics
  end


  ### MATCHER TYPES ###

  public

  class LinePattern < Solanum::Matcher
    def initialize(fn, pattern)
      super fn
      raise "pattern must be provided" if pattern.nil?
      @pattern = pattern
    end

    def call(metrics, lines)
      raise "lines must be provided" if lines.nil?
      raise "metrics must be provided" if metrics.nil?

      lines.reduce(metrics) do |m, line|
        begin
          if @pattern === line
            @fn.call(m, $~)
          else
            m
          end
        rescue => e
          STDERR.puts("Error calculating metrics from line match: #{e.inspect}")
          m
        end
      end
    end
  end
end
