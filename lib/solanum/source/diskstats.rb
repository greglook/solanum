require 'solanum/source'

class Solanum::Source::Diskstats < Solanum::Source
  attr_reader :devices

  STAT_FILE = '/proc/diskstats'

  FIELDS = %w{
    major minor name
    reads_completed reads_merged read_sectors read_time
    writes_completed writes_merged write_sectors write_time
    io_active io_time io_weighted_time
  }


  def initialize(opts)
    super(opts)
    @devices = opts['devices'] || []
    @detailed = opts['detailed'] || false
    @last = {}
  end


  def parse_stats(line)
    columns = line.strip.split(/\s+/)
    columns = columns.take(3) + columns.drop(3).map(&:to_i)
    Hash[FIELDS.zip(columns)]
  end


  def collect!
    events = []

    File.readlines(STAT_FILE).each do |line|
      stats = parse_stats(line)
      device = stats['name']

      if @devices.include?(device) || (@devices.empty? && device =~ /^sd[a-z]$/)
        if @last[device]
          diff = Hash.new(0)
          FIELDS.drop(3).each do |field|
            diff[field] = stats[field] - @last[device][field]
          end
          prefix = "diskstats #{device}"

          # Reads

          events << {
            service: "#{prefix} read sectors",
            metric: diff['read_sectors'],
          }

          events << {
            service: "#{prefix} read time",
            metric: diff['read_time'],
          }

          if @detailed
            events << {
              service: "#{prefix} read completed",
              metric: diff['reads_completed'],
            }

            events << {
              service: "#{prefix} read merged",
              metric: diff['reads_merged'],
            }
          end

          # Writes

          events << {
            service: "#{prefix} write sectors",
            metric: diff['write_sectors'],
          }

          events << {
            service: "#{prefix} write time",
            metric: diff['write_time'],
          }

          if @detailed
            events << {
              service: "#{prefix} write completed",
              metric: diff['writes_completed'],
            }

            events << {
              service: "#{prefix} write merged",
              metric: diff['writes_merged'],
            }
          end

          # IO

          events << {
            service: "#{prefix} io active",
            metric: diff['io_active'],
          }

          events << {
            service: "#{prefix} io time",
            metric: diff['io_time'],
          }

          events << {
            service: "#{prefix} io weighted-time",
            metric: diff['io_weighted_time'],
          }
        end
        @last[device] = stats
      end
    end

    events
  end

end
