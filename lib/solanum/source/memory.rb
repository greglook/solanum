require 'solanum/source'
require 'solanum/util'

class Solanum::Source::Memory < Solanum::Source
  attr_reader :thresholds, :swap_thresholds


  def initialize(opts)
    super(opts)
    @thresholds = opts['thresholds'] || {}
    @swap_thresholds = opts['swap_thresholds'] || {}
  end


  def collect!
    events = []

    meminfo = Hash.new(0)
    File.readlines('/proc/meminfo').each do |line|
      measure, quantity = *line.chomp.split(/: +/)
      value, unit = *quantity.split(' ')
      meminfo[measure] = value.to_i
    end

    mem_total = meminfo['MemTotal'].to_f
    record_usage = lambda do |type|
      if meminfo[type]
        usage_pct = meminfo[type]/mem_total.to_f
        events << {
          service: "memory #{type.downcase}",
          metric: usage_pct,
        }
      end
    end

    total_used = mem_total - meminfo['MemFree']
    mem_used = total_used - meminfo['Buffers'] - meminfo['Cached']
    usage = mem_used/mem_total
    events << {
      service: 'memory usage',
      metric: usage,
      state: state_over(@thresholds, usage),
    }

    events << {
      service: 'memory buffers',
      metric: meminfo['Buffers']/mem_total
    }

    cached = meminfo['Cached'] + meminfo['SReclaimable'] - meminfo['Shmem']
    events << {
      service: 'memory cached',
      metric: cached/mem_total
    }

    if meminfo['SwapTotal'] && meminfo['SwapTotal'] > 0
      swap_total = meminfo['SwapTotal']
      swap_free = meminfo['SwapFree']
      usage = 1.0 - swap_free/swap_total.to_f
      events << {
        service: 'swap usage',
        metric: usage,
        state: state_over(@swap_thresholds, usage),
      }
    end

    events
  end

end
