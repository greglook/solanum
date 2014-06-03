require 'solanum/source'


module Solanum
class Config
  attr_reader :sources, :services

  def initialize
    @sources = []
    @services = []
  end

  # Loads a monitor script.
  def load(path)
    instance_eval ::File.readlines(path).join, path, 1
  end


  private

  # Registers a new source object. If a block is given, it is used to configure
  # the source with instance_exec.
  def register_source(source, config=nil)
    source.instance_exec &config if config
    @sources << source
    source
  end


  # Registers a source which runs a command and matches against output lines.
  def run(command, &config)
    register_source Solanum::Source::Command.new(command), config
  end


  # Registers a source which matches against the lines in a file.
  def read(path, &config)
    register_source Solanum::Source::File.new(path), config
  end


  # Registers a source which computes metrics directly.
  def compute(&block)
    register_source Solanum::Source::Compute.new(block)
  end


  # Registers a pair of [matcher, prototype] where matcher is generally a string
  # or regex to match a service name, and prototype is a map of :ttl, :state,
  # :tags, etc.
  def service(service, prototype={})
    @services << [service, prototype]
  end


  ##### HELPER METHODS #####

  # Creates a state function based on thresholds. If the first argument is a
  # symbol, it is taken as the default service state. Otherwise, arguments should
  # be alternating numeric thresholds and state values to assign if the metric
  # value exceeds the threshold.
  #
  # For example, for an 'availability' metric you often want to warn on low
  # values. To assign a 'critical' state to values between 0% and 10%,
  # 'warning' between 10% and 25%, and 'ok' above, use the following:
  #
  #     thresholds(0.00, :critical, 0.10, :warning, 0.25, :ok)
  #
  # For 'usage' metrics it's the inverse, giving low values ok states and
  # warning about high values:
  #
  #     thresholds(:ok, 55, :warning, 65, :critical)
  #
  def thresholds(*args)
    default_state = nil
    default_state = args.shift unless args.first.kind_of? Numeric

    # Check arguments.
    raise "Thresholds must be paired with state values" unless args.count.even?
    args.each_slice(2) do |threshold|
      limit, state = *threshold
      raise "Limits must be numeric: #{limit}" unless limit.kind_of? Numeric
      raise "State values must be strings or symbols: #{state}" unless state.instance_of?(String) || state.instance_of?(Symbol)
    end

    # State block.
    lambda do |v|
      state = default_state
      args.each_slice(2) do |threshold|
        if threshold[0] < v
          state = threshold[1]
        else
          break
        end
      end
      state
    end
  end

end
end
