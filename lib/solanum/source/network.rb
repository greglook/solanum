require 'solanum/source'

# bytes - The total number of bytes of data transmitted or received by the interface.
# packets - The total number of packets of data transmitted or received by the interface.
# errs - The total number of transmit or receive errors detected by the device driver.
# drop - The total number of packets dropped by the device driver.
# fifo - The number of FIFO buffer errors.
# frame - The number of packet framing errors.
# colls - The number of collisions detected on the interface.
# compressed - The number of compressed packets transmitted or received by the device driver. (This appears to be unused in the 2.2.15 kernel.)
# carrier - The number of carrier losses detected by the device driver.
# multicast - The number of multicast frames transmitted or received by the device driver.
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
