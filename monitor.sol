# Solanum monitoring configuration
# vim: ft=ruby


compute do
    
    # Utility procedure to calculate utilization metrics.
    def rate_of(metric, new_value, unit, scale=1.0)
        old_value = metric.value unit
        return nil unless old_value
        
        dv = new_value - old_value
        dt = Time.now  - metric.time
        r = ( dt > 0 ) ? scale.to_f*dv/dt : nil
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
        next unless total
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

interfaces = ['wan0', 'lan0', 'wlan0']

# network interface utilization
read "/proc/net/dev" do
    interfaces.each do |dev|
        match /^\s*#{dev}:\s*(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+$/ do |m|
            # calculate io utilization from cumulative data transferred and
            # packets since system boot
            %w{rx tx}.each_with_index do |name, i|
                metric = get_metric "system.net.#{dev}.io.#{name}"
                data  = m[2*i+0].to_i
                count = m[2*i+1].to_i
                
                kbit = rate_of metric, data, :bytes, 8.0/1024
                rate = rate_of metric, count, :packets
                
                metric.record data, :bytes
                metric.record kbit, :kbit
                metric.record count, :packets
                metric.record rate, :pps
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

