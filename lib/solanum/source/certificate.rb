require 'openssl'
require 'socket'
require 'solanum/source'
require 'solanum/util'

class Solanum::Source::Certificate < Solanum::Source
  attr_reader :host, :port, :ca_cert, :expiry_states


  def initialize(opts)
    super(opts)
    @host = opts['host'] or raise "No host provided"
    @port = opts['port'] || 443
    @hostname = opts['hostname'] || @host
    @ca_cert = opts['ca_cert']
    @expiry_states = opts['expiry_states'] || {}
  end


  def connect
    # Configure context.
    ctx = OpenSSL::SSL::SSLContext.new
    #ctx.verify_hostname = true  # Only in ruby 2.x?

    if @ca_cert
      ctx.ca_file = @ca_cert
      ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end

    # Open socket connection.
    sock = TCPSocket.new(@host, @port)
    ssl = OpenSSL::SSL::SSLSocket.new(sock, ctx)
    ssl.sync_close = true
    ssl.hostname = @hostname
    ssl.connect

    yield ssl if block_given?
  ensure
    if ssl
      ssl.close
    elsif sock
      sock.close
    end
  end


  # Collect metric events.
  def collect!
    events = []
    prefix = "certificate #{@hostname}"

    begin
      connect do |ssl|
        cert = ssl.peer_cert

        # Connect okay.
        events << {
          service: "#{prefix} connect",
          metric: 1,
          state: 'ok',
          description: "Certificate for #{@hostname} verified successfully",
        }

        # Certificate expiration time.
        #puts cert.inspect
        expiry = cert.not_after - Time.now
        expiry_days = expiry/86400
        events << {
          service: "#{prefix} expiry",
          metric: expiry_days,
          state: state_under(@expiry_states, expiry_days),
          description: "Certificate for #{@hostname} expires in #{duration_str(expiry)}",
        }
      end
    rescue => e
      # Connect error.
      events << {
        service: "#{prefix} connect",
        metric: 1,
        state: 'critical',
        description: "Error connecting to #{@hostname}: #{e}",
      }
    end

    events
  end

end
