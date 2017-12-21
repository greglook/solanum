require 'solanum/config'
require 'solanum/schedule'
require 'thread'


# Class which wraps up an active Solanum monitoring system into an object.
class Solanum
  attr_reader :defaults, :sources, :outputs

  # Merge two event attribute maps together, concatenating tags.
  def self.merge_attrs(a, b)
    stringify = lambda do |x|
      o = {}
      x.keys.each do |k|
        o[k.to_s] = x[k]
      end
      o
    end

    if a.nil?
      stringify[b]
    elsif b.nil?
      stringify[a]
    else
      a = stringify[a]
      b = stringify[b]
      tags = a['tags'] ? a['tags'].dup : []
      tags.concat(b['tags']) if b['tags']
      tags.uniq!
      x = a.dup.merge(b)
      x['tags'] = tags unless tags.empty?
      x
    end
  end


  # Loads the given configuration file(s) and initializes the system.
  def initialize(config_paths)
    @defaults = {tags: []}
    @sources = []
    @outputs = []

    # Load and merge files.
    config_paths.each do |path|
      conf = Config.load_file(path)

      # merge defaults, update tags
      @defaults = Solanum.merge_attrs(@defaults, conf[:defaults])

      # sources and outputs are additive
      @sources.concat(conf[:sources])
      @outputs.concat(conf[:outputs])
    end

    # Add default print output.
    if @outputs.empty?
      require 'solanum/output/print'
      @outputs << Solanum::Output::Print.new()
    end

    @defaults.freeze
    @outputs.freeze
    @sources.freeze

    @schedule = Solanum::Schedule.new
    @sources.each_with_index do |source, i|
      @schedule.insert!(source.next_run, i)
    end
  end


  # Reschedule the given source for later running.
  def reschedule!(source)
    idx = nil
    @sources.each_with_index do |s, i|
      if s == source
        idx = i
        break
      end
    end
    raise "Source #{source.inspect} is not present in source list!" unless idx
    @schedule.insert!(source.next_run, idx)
  end


  # Report a batch of events to all reporters.
  def record!(events)
    # TODO: does this need locking?
    @outputs.each do |output|
      output.write_events events
    end
  end


  # Runs the collection loop.
  def run!
    puts self.inspect
    loop do
      # Determine when next scheduled source should run, and sleep if needed.
      duration = @schedule.next_wait || 1
      if 0 < duration
        sleep duration
        next
      end

      # Get the next ready source.
      idx = @schedule.pop_ready!
      source = @sources[idx] if idx
      next unless source
      puts "Source #{source.type} is ready to run!" # DEBUG

      # Start thread to collect and report events.
      Thread.new do
        events = source.collect!
        attrs = Solanum.merge_attrs(@defaults, source.attributes)
        events = events.map do |event|
          Solanum.merge_attrs(attrs, event)
        end
        record! events
        reschedule! source
      end
    end
  end

end
