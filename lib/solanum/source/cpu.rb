require 'solanum/source'
require 'solanum/util'

class Solanum::Source::Cpu < Solanum::Source
  attr_reader :detailed, :per_core, :thresholds

  STAT_FILE = '/proc/stat'
  STATES = %w{user nice system idle iowait irqhard irqsoft}


  def initialize(opts)
    super(opts)
    @last = nil
    @detailed = opts['detailed'] || false
    @per_core = opts['per_core'] || false
    @thresholds = opts['thresholds'] || {}
  end


  # Calculate cpu utilization from the cumulative time spent in
  # 'jiffies' (1/100 sec) since system boot.
  def parse_info(line)
    fields = line.chomp.split(' ')
    name = fields.shift
    data = Hash.new(0)
    STATES.each_with_index do |state, i|
      data[state] = fields[i].to_i
    end
    return name, data
  end


  # Collect metric events.
  def collect!
    # Parse lines from usage stats.
    lines = File.readlines(STAT_FILE).take_while {|l| l.start_with? 'cpu' }
    totals = {}
    lines.each do |line|
      name, data = parse_info(line)
      totals[name] = data
    end

    # Need at least one run to start reporting accurate metrics.
    unless @last
      @last = totals
      return []
    end

    # Calculate diffs from previous measurements.
    diffs = {}
    totals.each do |name, data|
      diffs[name] = Hash.new(0)
      data.each do |state, jiffies|
        last = @last[name] && @last[name][state]
        diffs[name][state] = jiffies - last if last
      end
    end
    @last = totals

    # Convert diffs to relative percentages.
    diffs.each do |name, diff|
      elapsed = diff.values.reduce(&:+)
      diff.keys.each do |state|
        diff[state] = diff[state].to_f/elapsed
      end
    end

    # Generate metric events.
    events = []

    # aggregate cpu usage
    usage = 1.0 - diffs['cpu']['idle']
    events << {
      service: 'cpu usage',
      metric: usage,
      state: state_over(@thresholds, usage),
    }

    # detailed aggregate cpu state metrics
    if @detailed
      diffs['cpu'].each do |state, usage|
        events << {
          service: 'cpu state',
          metric: usage,
          cpu_state: state,
        }
      end
    end

    # even more detailed per-core usage
    if @per_core
      diffs.each do |name, diff|
        next if name == 'cpu'

        usage = 1.0 - diff['idle']
        events << {
          service: 'cpu core usage',
          metric: usage,
          state: state_over(@thresholds, usage),
          cpu_core: name,
        }

        if @detailed
          diff.each do |state, usage|
            events << {
              service: 'cpu core state',
              metric: usage,
              cpu_core: name,
              cpu_state: state,
            }
          end
        end
      end
    end

    events
  end

end
