require 'riemann/client'

class Solanum
class Output
class Riemann

  def initialize(args)
    @client = ::Riemann::Client.new(host: args['host'], port: args['port'])
  end

  def write_events(events)
    # OPTIMIZE: batch events?
    events.each do |event|
      @client << event
    end
  end

end
end
end
