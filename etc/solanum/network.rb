# Solanum monitoring configuration for network interface metrics.
#
# Author:: Greg Look

# autodetect network interfaces
interfaces = []
File.open("/proc/net/dev") do |f|
  f.each do |line|
    interfaces << $1 if f.lineno > 2 && /^\s*(\w+)/ === line
  end
end
puts "Detected network interfaces: #{interfaces.join(', ')}"

# network interface utilization
read "/proc/net/dev" do
  interfaces.each do |dev|
    match /^\s*#{dev}:\s*(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+$/ do |m|
      # calculate io utilization from cumulative data transferred and
      # packets since system boot
      %w{rx tx}.each_with_index do |type, i|
        metric = get_metric "system.net.#{dev}.io.#{type}"
        metric.record_rate :pps, m[2*i+1].to_i, :packets
        metric.record_rate :kbit, m[2*i+0].to_i, :bytes, 8.0/1024
      end
    end
  end
end

# interface link and address information
interfaces.each do |dev|
  run "ip address show #{dev}" do
    match /^\d+: #{dev}: <.+> mtu (\d+)/, :record => "system.net.#{dev}.link.mtu", :as => :to_i, :unit => :bytes
    match /^\s*link\/([\w.\/]+) ([0-9a-f:]+) brd ([0-9a-f:]+)/ do |m|
      record "system.net.#{dev}.link.type",    m[1].to_s
      record "system.net.#{dev}.link.address",   m[2].to_s
      record "system.net.#{dev}.link.broadcast", m[3].to_s
    end
    match /^\s*inet ([\d.]+)\/(\d+) brd ([\d.]+) scope (\w+)/ do |m|
      record "system.net.#{dev}.inet.address",   m[1].to_s
      record "system.net.#{dev}.inet.mask",    m[2].to_i
      record "system.net.#{dev}.inet.broadcast", m[3].to_s
      record "system.net.#{dev}.inet.scope",   m[4].to_s
    end
    match /^\s*inet6 ([0-9a-f:]+)\/(\d+) scope (\w+)/ do |m|
      record "system.net.#{dev}.inet6.address",  m[1].to_s
      record "system.net.#{dev}.inet6.mask",   m[2].to_i
      record "system.net.#{dev}.inet6.scope",  m[3].to_s
    end
  end
end
