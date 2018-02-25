require 'solanum/source'

class Solanum::Source::Uptime < Solanum::Source

  STAT_FILE = '/proc/uptime'


  def initialize(opts)
    super(opts)
  end


  def collect!
    events = []

    uptime = File.read(STAT_FILE).split(' ').first.to_f

    events << {
      service: 'uptime',
      metric: uptime,
      description: "Up for #{duration_str(uptime)}",
    }

    events
  end

end
