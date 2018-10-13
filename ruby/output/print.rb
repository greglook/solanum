class Solanum
class Output
class Print
  def initialize(args)
  end

  def write_events(events)
    events.each do |event|
      puts "%-40s %5s (%s) %s" % [
        event['service'], event['metric'],
        event['state'].nil? ? "--" : event['state'],
        event.inspect
      ]
    end
  end
end
end
end
