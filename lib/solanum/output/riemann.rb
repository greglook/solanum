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
      ev = {}
      event.each {|k,v| ev[k.intern] = v }
      @client << ev
    end
  end

end
end
end
