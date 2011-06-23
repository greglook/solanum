# Solanum monitoring configuration
# vim: ft=ruby


LO_IF = 'lo'
LAN_IF = 'br0'
WAN_IF = 'ppp0'

metrics_helpers do
    
    # Calculates the rate of change in of the metric value in the given unit
    # type, optionaly multiplied by a scalar value.
    def rate_of(metric, new_value, unit, scale=1.0)
        old_value = metric.value unit
        return nil unless old_value
        
        dv = new_value - old_value
        dt = Time.now  - metric.time
        r = ( dt > 0 ) ? scale.to_f*dv/dt : nil
    end
    
    # Records simple network traffic metrics based on cumulative transferred
    # byte and packet counts.
    def record_traffic(name, packets, bytes)
        metric = get_metric name
        pps = rate_of metric, packets, :packets
        kbit = rate_of metric, bytes, :bytes, 8.0/1024
        
        metric.record bytes, :bytes
        metric.record kbit, :kbit
        metric.record packets, :packets
        metric.record pps, :pps
    end
    
end



##### SYSTEM STATUS #####

# hardware sensor data
run "/usr/bin/sensors" do
    match /^Core 0:\s+\+(\d+\.\d+)°C/, :record => "system.sensor.coretemp", :as => :to_f, :unit => :C
    match /^temp1:\s+\+(\d+\.\d+)°C/,  :record => "system.sensor.temp1",    :as => :to_f, :unit => :C
    match /^temp2:\s+\+(\d+\.\d+)°C/,  :record => "system.sensor.temp2",    :as => :to_f, :unit => :C
    match /^temp3:\s+\+(\d+\.\d+)°C/,  :record => "system.sensor.temp3",    :as => :to_f, :unit => :C
end

# system uptime
read "/proc/uptime" do
    match /^(\d+\.\d+)/, :record => "system.uptime", :as => :to_f, :unit => :seconds
end

# system load
read "/proc/loadavg" do
    match /^(\d+\.\d+) \d+\.\d+ \d+\.\d+ (\d+)\/(\d+) \d+$/ do |m|
        record "system.process.load",    m[1].to_f
        record "system.process.running", m[2].to_i
        record "system.process.count",   m[3].to_i
    end
end

# cpu frequency
read "/proc/cpuinfo" do
    match /^cpu MHz\s*:\s+(\d+\.\d+)/, :record => "system.cpu.frequency", :as => :to_f, :unit => :MHz
end

# cpu utilization
read "/proc/stat" do
    match /^cpu(\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+)/ do |m|
        core = m[1].to_i
        
        # calculate cpu utilization from the cumulative time spent in
        # 'jiffies' (1/100 sec) since system boot
        %w{user nice system idle iowait irqhard irqsoft}.each_with_index do |name, i|
            metric = get_metric "system.cpu.core#{core}.#{name}"
            value = m[i+2].to_i
            r = rate_of metric, value, :jiffies
            metric.record value, :jiffies
            metric.record r, :%
        end
    end
end

# memory usage
read "/proc/meminfo" do
    match /^MemTotal:\s+(\d+) kB$/,  :record => "system.memory.total",   :as => :to_i, :unit => :kB
    match /^MemFree:\s+(\d+) kB$/,   :record => "system.memory.free",    :as => :to_i, :unit => :kB
    match /^Buffers:\s+(\d+) kB$/,   :record => "system.memory.buffers", :as => :to_i, :unit => :kB
    match /^Cached:\s+(\d+) kB$/,    :record => "system.memory.cached",  :as => :to_i, :unit => :kB
    
    match /^SwapTotal:\s+(\d+) kB$/, :record => "system.swap.total",     :as => :to_i, :unit => :kB
    match /^SwapFree:\s+(\d+) kB$/,  :record => "system.swap.free",      :as => :to_i, :unit => :kB
end

# calculate percentages from total space
compute do
    [%w{system.memory free buffers cached},
     %w{system.swap   free}].each do |info|
        parent = info.shift
        total = get_metric("#{parent}.total").value :kB
        next unless total && total > 0
        info.each_with_index do |name, i|
            metric = get_metric "#{parent}.#{name}"
            used = metric.value :kB
            metric.record 100.0*used/total, :% if used
        end
    end
end



##### DISK INFORMATION #####

# determine disk devices to monitor
disks = Dir['/dev/sd*'].map{|dev| dev[5..7] }.uniq.sort

# SMART health
disks.each do |dev|
    run "/usr/sbin/smartctl -HA /dev/#{dev}" do
        match /^SMART overall\-health self\-assessment test result: (\w+)$/, :record => "system.disk.#{dev}.smart"
        match /^\s*9\s+Power_On_Hours\s+0x\d+\s+\d+\s+\d+\s+\d+\s+\w+\s+\w+\s+\S+\s+(\d+)$/, :record => "system.disk.#{dev}.age", :as => :to_i, :unit => :hours
        match /^\s*194\s+Temperature_Celsius\s+0x\d+\s+\d+\s+\d+\s+\d+\s+\w+\s+\w+\s+\-\s+(\d+)$/, :record => "system.disk.#{dev}.temp", :as => :to_i, :unit => :C
    end
end

# disk utilization
read "/proc/diskstats" do
    disks.each do |dev|
        match /^\s*\d+\s+\d+\s+#{dev}\s+\d+\s+\d+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+$/ do |m|
            # calculate io utilization from the cumulative 512B sector count
            # since system boot
            %w{read write}.each_with_index do |name, i|
                metric = get_metric "system.disk.#{dev}.io.#{name}"
                value = m[i+1].to_i
                r = rate_of metric, value, :sectors
                metric.record value, :sectors
                metric.record r, :kBps
            end
        end
    end
end



##### NETWORK STATUS #####

interfaces = ['wan0', 'lan0', 'wlan0', 'br0', 'ppp0']

# network interface utilization
read "/proc/net/dev" do
    interfaces.each do |dev|
        match /^\s*#{dev}:\s*(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+$/ do |m|
            # calculate io utilization from cumulative data transferred and
            # packets since system boot
            %w{rx tx}.each_with_index do |type, i|
                record_traffic "system.net.#{dev}.io.#{type}", m[2*i+1].to_i, m[2*i+0].to_i
            end
        end
    end
end

# interface link and address information
interfaces.each do |dev|
    run "/sbin/ip address show #{dev}" do
        match /^\d+: #{dev}: <.+> mtu (\d+)/, :record => "system.net.#{dev}.link.mtu", :as => :to_i, :unit => :bytes
        match /^\s*link\/([\w.\/]+) ([0-9a-f:]+) brd ([0-9a-f:]+)/ do |m|
            record "system.net.#{dev}.link.type",      m[1].to_s
            record "system.net.#{dev}.link.address",   m[2].to_s
            record "system.net.#{dev}.link.broadcast", m[3].to_s
        end
        match /^\s*inet ([\d.]+)\/(\d+) brd ([\d.]+) scope (\w+)/ do |m|
            record "system.net.#{dev}.inet.address",   m[1].to_s
            record "system.net.#{dev}.inet.mask",      m[2].to_i
            record "system.net.#{dev}.inet.broadcast", m[3].to_s
            record "system.net.#{dev}.inet.scope",     m[4].to_s
        end
        match /^\s*inet6 ([0-9a-f:]+)\/(\d+) scope (\w+)/ do |m|
            record "system.net.#{dev}.inet6.address",  m[1].to_s
            record "system.net.#{dev}.inet6.mask",     m[2].to_i
            record "system.net.#{dev}.inet6.scope",    m[3].to_s
        end
    end
end



##### FIREWALL STATISTICS #####

input_helpers do
    
    # Matches an iptables rule and records traffic statistics.
    def match_rule(name, props={})
        pattern = /^\s*(\d+)\s+(\d+)\s+#{props[:target] || 'ACCEPT'}\s+#{props[:proto] || 'all'}\s+\-\-\s+#{props[:in] || 'any'}\s+#{props[:out] || 'any'}\s+#{props[:source] || 'anywhere'}\s+#{props[:dest] || 'anywhere'}\s*#{props[:match] || ''}/
        match pattern do |m| record_traffic name, m[1].to_i, m[2].to_i end
    end
    
end


# FILTER:INPUT chain
run "iptables --list INPUT --verbose --exact" do
    match /^Chain INPUT \(policy (\w+) (\d+) packets, (\d+) bytes\)/ do |m|
        record "firewall.filter.input.policy", m[1].to_s
        record_traffic "firewall.filter.input.default", m[2].to_i, m[3].to_i
    end
    match_rule "firewall.filter.input.lan", :in => LAN_IF
    match_rule "firewall.filter.input.loopback", :in => LO_IF
    match_rule "firewall.filter.input.established", :in => WAN_IF, :match => 'state RELATED,ESTABLISHED'
end


# FILTER:OUTPUT chain
run "iptables --list OUTPUT --verbose --exact" do
    match /^Chain OUTPUT \(policy (\w+) (\d+) packets, (\d+) bytes\)/ do |m|
        record "firewall.filter.output.policy", m[1].to_s
        record_traffic "firewall.filter.output.default", m[2].to_i, m[3].to_i
    end
end


# FILTER:FORWARD chain
run "iptables --list FORWARD --verbose --exact" do
    match /^Chain FORWARD \(policy (\w+) (\d+) packets, (\d+) bytes\)/ do |m|
        record "firewall.filter.forward.policy", m[1].to_s
        record_traffic "firewall.filter.forward.default", m[2].to_i, m[3].to_i
    end
    match_rule "firewall.filter.forward.lan", :in => LAN_IF
    match_rule "firewall.filter.forward.established", :match => 'state RELATED,ESTABLISHED'
end


# MANGLE:mark_qos_band chain
run "iptables --table mangle --list mark_qos_band --verbose --exact" do
    match_rule "firewall.mangle.qos.band1", :target => 'RETURN', :match => 'mark match 0x1'
    match_rule "firewall.mangle.qos.band2", :target => 'RETURN', :match => 'mark match 0x2'
    match_rule "firewall.mangle.qos.band3", :target => 'RETURN', :match => 'mark match 0x3'
    match_rule "firewall.mangle.qos.band4", :target => 'RETURN', :match => 'mark match 0x4'
    match_rule "firewall.mangle.qos.band5", :target => 'RETURN', :match => 'mark match 0x5'
end

