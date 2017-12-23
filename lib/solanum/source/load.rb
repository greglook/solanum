require 'solanum/source'
require 'solanum/util'

class Solanum::Source::Load < Solanum::Source
  attr_reader :thresholds

  STAT_FILE = '/proc/loadavg'


  def initialize(opts)
    super(opts)
    @thresholds = opts['thresholds'] || {}
  end


  def collect!
    events = []

    loadavg = File.read(STAT_FILE).chomp.split(' ')

    load1m = loadavg[0].to_f

    events << {
      service: 'process load',
      metric: load1m,
      state: state_over(@thresholds, load1m),
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
