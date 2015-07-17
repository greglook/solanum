# A matcher takes in an input string and returns a hash of measurement names to
# numeric values.
#
# Author:: Greg Look
class Solanum::Matcher
  attr_reader :fn

  # Creates a new Matcher which will run the given function on input.
  def initialize(fn)
    raise "function must be provided" if fn.nil?
    @fn = fn
  end

  # Attempts to match the given input, returning a hash of metrics.
  def call(input)
    {}
  end


  ### MATCHER TYPES ###

  public

  # LinePattern matchers define a regular expression which is tested against
  # each line of input. The given function is called for **each** matched line,
  # and the resulting measurements are merged together.
  class LinePattern < Solanum::Matcher
    def initialize(fn, pattern)
      super fn
      raise "pattern must be provided" if pattern.nil?
      @pattern = pattern
    end

    def call(input)
      raise "No input provided!" if input.nil?
      lines = input.split("\n")
      metrics = {}

      lines.each do |line|
        begin
          if @pattern === line
            measurements = @fn.call($~)
            metrics.merge!(measurements) if measurements
          end
        rescue => e
          STDERR.puts("Error calculating metrics from line match: #{e.inspect}")
        end
      end

      metrics
    end
  end
end
