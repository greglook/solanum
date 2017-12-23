require 'solanum/source'

class Solanum::Source::Uptime < Solanum::Source

  STAT_FILE = '/proc/uptime'


  def initialize(opts)
    super(opts)
    @thresholds = opts['thresholds'] || {}
  end


  def collect!
    events = []

    uptime = File.read(STAT_FILE).split(' ').first.to_f

    days = (uptime/86400).to_i
    hours = ((uptime % 86400)/3600).to_i
    minutes = ((uptime % 3600)/60).to_i
    seconds = (uptime % 60).to_i
    duration = "%02d:%02d:%02d" % [hours, minutes, seconds]

    events << {
      service: 'uptime',
      metric: uptime,
      description: "Up for #{days} days, #{duration}",
    }

    events
  end

end
