require 'solanum/source'

class Solanum::Source::Network < Solanum::Source
  attr_reader :interfaces, :detailed

  STAT_FILE = '/proc/net/dev'

  FIELDS = %w{
    rx_bytes rx_packets rx_errs rx_drop rx_fifo rx_frame rx_compressed rx_multicast
    tx_bytes tx_packets tx_errs tx_drop tx_fifo tx_colls tx_carrier tx_compressed
  }

  SIMPLE_FIELDS = %w{rx_bytes rx_packets tx_bytes tx_packets}


  def initialize(opts)
    super(opts)
    @interfaces = opts['interfaces'] || []
    @detailed = opts['detailed'] || false
    @last = {}
  end


  def parse_stats(line)
    columns = line.strip.split(/\s+/)
    iface = columns.shift.chomp(':')
    return iface, Hash[FIELDS.zip(columns.map(&:to_i))]
  end


  def collect!
    events = []

    File.readlines(STAT_FILE).drop(2).each do |line|
      iface, stats = parse_stats(line)

      if @interfaces.empty? || @interfaces.include?(iface)
        if @last[iface]
          FIELDS.each do |field|
            next unless @detailed || SIMPLE_FIELDS.include?(field)
            diff = stats[field] - @last[iface][field]
            events << {
              service: "net #{iface} #{field.gsub('_', ' ')}",
              metric: diff,
            }
          end
        end
        @last[iface] = stats
      end
    end

    events
  end

end
