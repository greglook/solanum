require 'solanum/source'

class Solanum::Source::Load < Solanum::Source
  attr_reader :thresholds

  STAT_FILE = '/proc/loadavg'


  def initialize(opts)
    super(opts)
    @thresholds = opts['thresholds'] || {}
  end


  def collect!
    events = []

    uptime = File.read('/proc/uptime').split(' ').first.to_f
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

    loadavg = File.read(STAT_FILE).chomp.split(' ')

    load1m = loadavg[0].to_f
    events << {
      service: 'process load',
      metric: load1m,
      state: event_state(load1m),
    }

    running, count = *loadavg[3].split('/')
    events << {
      service: 'process running',
      metric: running.to_i,
    }
    events << {
      service: 'process count',
      metric: count.to_i,
    }

    events
  end

end
