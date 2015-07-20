require 'solanum/matcher'

# This class represents a source of data, whether read from command output,
# a file on the system, or just calculated from other values. Each source
# may have multiple matchers, which will be run against the input data to
# produce metrics. Each matcher sees the _whole_ input.
#
# Author:: Greg Look
class Solanum::Source
  attr_reader :config, :matchers

  # Creates a new Source
  def initialize(config)
    @config = config
    @matchers = []
  end

  # Collect input and process it with the defined matchers to produce some
  # output measurements. The current set of metrics collected in this cycle
  # will be passed to the measure function.
  def collect(current_metrics)
    input = read_input!
    metrics = {}

    unless input.nil?
      @matchers.each do |matcher|
        measurements = matcher.call(input)
        metrics.merge!(measurements) if measurements
      end
    end

    metrics
  end

  private

  # Collect input data from the given source.
  def read_input!
    nil
  end

  # Declares a matcher for a single line of input.
  def match(pattern, options={}, &block)
    raise "pattern must be provided" if pattern.nil?

    commands = 0
    commands += 1 if options[:record]
    commands += 1 if block_given?
    raise "Must specify :record or provide a block to execute" if commands == 0
    raise "Only one of :record or a block should be provided" if commands > 1

    if options[:record]
      block = lambda do |matches|
        value = matches[1]
        value = value.send(options[:cast]) if options[:cast]
        value *= options[:scale] if options[:scale]
        {options[:record] => value}
      end
    end

    @matchers << Solanum::Matcher::LinePattern.new(block, pattern)
  end

  # Declares a matcher for JSON input.
  def json(&block)
    @matchers << Solanum::Matcher::JSONReader.new(block)
  end



  ### SOURCE TYPES ###

  public

  class File < Solanum::Source
    def read_input!
      # Check that file exists and is readable.
      raise "File does not exist: #{@config}" unless ::File.exists? @config
      raise "File is not readable: #{@config}" unless ::File.readable? @config

      # Read lines from the file.
      ::File.read(@config)
    end
  end

  class Command < Solanum::Source
    def read_input!
      # Locate absolute command path.
      command, args = @config.split(/\s/, 2)
      abs_command =
        if ::File.executable? command
          command
        else
          %x{which #{command} 2> /dev/null}.chomp
        end

      # Check that command exists and is executable.
      raise "Command #{command} not found" unless ::File.exist? abs_command
      raise "Command #{abs_command} not executable" unless ::File.executable? abs_command

      # Run command for output.
      input = %x{#{abs_command} #{args}}
      raise "Error executing command: #{abs_command} #{args}" unless $?.success?

      input
    end
  end

  class Compute < Solanum::Source
    def collect(current_metrics)
      # Compute metrics directly, but don't let the block change the existing
      # metrics in-place.
      @config.call(current_metrics.dup.freeze)
    end
  end
end
