require 'solanum/config'


# Class which wraps up an active Solanum monitoring system into an object.
class Solanum
  attr_reader :defaults, :sources, :outputs

  # Loads the given configuration file(s) and initializes the system.
  def initialize(config_paths)
    @defaults = {tags: []}
    @sources = []
    @outputs = []

    # Load and merge files.
    config_paths.each do |path|
      conf = Config.load_file(path)

      # merge defaults, update tags
      conf_defaults = conf[:defaults] || {}
      tags = @defaults[:tags].concat(conf_defaults[:tags] || [])
      @defaults.merge(conf_defaults)
      @defaults[:tags] = tags

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
  end


  # ...?
  def next_source
    # ???
    @sources.sort_by(&:run_at).first
  end


  # Runs the collection loop.
  def run!
    puts self.inspect
    # ...
    # determine when next run of each source should happen
    # sleep until first scheduled run
    # start thread to collect events from next source
    #   - when done, thread should report events
    #   - set next scheduled run of source based on period
  end

end
