# Solanum monitoring configuration
# vim: ft=ruby


# Utility procedure to calculate utilization metrics.
rate = lambda do |metric, from_unit, scale|
    records = metric.records.select {|r| r.unit == from_unit }
    
    if records.length > 1
        a = records[records.length - 1]
        b = records[records.length - 2]
        dv = a.value - b.value
        dt = a.time  - b.time
        (( dv >= 0 ) && ( dt > 0 )) ? scale.to_f*dv/dt : nil
    else
        nil
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
    match /^(\d+\.\d+)/, :measure => "system.uptime", :as => :to_f, :unit => :seconds
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
    cores = [0, 1]
    cores.each do |i|
        match /^cpu#{i} (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+)/ do |m|
            user_metric    = "system.cpu.core#{i}.user"
            nice_metric    = "system.cpu.core#{i}.nice"
            system_metric  = "system.cpu.core#{i}.system"
            idle_metric    = "system.cpu.core#{i}.idle"
            iowait_metric  = "system.cpu.core#{i}.iowait"
            irqhard_metric = "system.cpu.core#{i}.irqhard"
            irqsoft_metric = "system.cpu.core#{i}.irqsoft"
            
            # cumulative time spent in 'jiffies' (1/100 sec) since system boot
            record user_metric,    m[1].to_i, :unit => :jiffies
            record nice_metric,    m[2].to_i, :unit => :jiffies
            record system_metric,  m[3].to_i, :unit => :jiffies
            record idle_metric,    m[4].to_i, :unit => :jiffies
            record iowait_metric,  m[5].to_i, :unit => :jiffies
            record irqhard_metric, m[6].to_i, :unit => :jiffies
            record irqsoft_metric, m[7].to_i, :unit => :jiffies
            
            # calculate cpu utilization
            utilization = lambda {|path| rate[resolve(path), :jiffies, 1.0] }
            record user_metric,    utilization[user_metric,   ], :unit => :%
            record nice_metric,    utilization[nice_metric,   ], :unit => :%
            record system_metric,  utilization[system_metric, ], :unit => :%
            record idle_metric,    utilization[idle_metric,   ], :unit => :%
            record iowait_metric,  utilization[iowait_metric, ], :unit => :%
            record irqhard_metric, utilization[irqhard_metric,], :unit => :%
            record irqsoft_metric, utilization[irqsoft_metric,], :unit => :%
        end
    end
end

# memory usage
read "/proc/meminfo" do
    match /^MemTotal:\s+(\d+) kB$/,  :measure => "system.memory.total",   :as => :to_i, :unit => :kB
    match /^MemFree:\s+(\d+) kB$/,   :record  => "system.memory.free",    :as => :to_i, :unit => :kB
    match /^Buffers:\s+(\d+) kB$/,   :record  => "system.memory.buffers", :as => :to_i, :unit => :kB
    match /^Cached:\s+(\d+) kB$/,    :record  => "system.memory.cached",  :as => :to_i, :unit => :kB
    
    match /^SwapTotal:\s+(\d+) kB$/, :measure => "system.swap.total",     :as => :to_i, :unit => :kB
    match /^SwapFree:\s+(\d+) kB$/,  :record  => "system.swap.free",      :as => :to_i, :unit => :kB
    
    # TODO: percentages
end



##### DISK INFORMATION #####

disks = Dir['/dev/sd*'].map{|dev| dev[5..7] }.uniq.sort

# SMART health
disks.each do |dev|
    run "/usr/sbin/smartctl -HA /dev/#{dev}" do
        match /^SMART overall\-health self\-assessment test result: (\w+)$/, :measure => "system.disk.#{dev}.smart"
        match /^\s*9\s+Power_On_Hours\s+0x\d+\s+\d+\s+\d+\s+\d+\s+\w+\s+\w+\s+\S+\s+(\d+)$/, :measure => "system.disk.#{dev}.age", :as => :to_i, :unit => :hours
        match /^\s*194\s+Temperature_Celsius\s+0x\d+\s+\d+\s+\d+\s+\d+\s+\w+\s+\w+\s+\-\s+(\d+)$/, :record => "system.disk.#{dev}.temp", :as => :to_i, :unit => :C
    end
end

# disk utilization
read "/proc/diskstats" do
    disks.each do |dev|
        match /^\s*\d+\s+\d+\s+#{dev}\s+\d+\s+\d+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+$/ do |m|
            read_metric = "system.disk.#{dev}.io.read"
            write_metric = "system.disk.#{dev}.io.write"
            
            # cumulative 512B sectors since system boot
            record read_metric,  m[1].to_i, :unit => :sectors
            record write_metric, m[2].to_i, :unit => :sectors
            
            # calculate io utilization
            utilization = lambda {|path| rate[resolve(path), :sectors, 0.5] }
            record read_metric,  utilization[read_metric ], :unit => :kBps
            record write_metric, utilization[write_metric], :unit => :kBps
        end
    end
end



##### NETWORK STATUS #####

interfaces = ['wan0', 'lan0', 'wlan0']

# network interface utilization
read "/proc/net/dev" do
    interfaces.each do |dev|
        match /^\s*#{dev}:\s*(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+$/ do |m|
            rx_metric = "system.net.#{dev}.io.rx"
            tx_metric = "system.net.#{dev}.io.tx"
            
            # cumulative since system boot
            record rx_metric, m[1].to_i, :unit => :bytes
            record rx_metric, m[2].to_i, :unit => :packets
            record tx_metric, m[3].to_i, :unit => :bytes
            record tx_metric, m[4].to_i, :unit => :packets
            
            # calculate io bandwidth
            bandwidth = lambda {|path| rate[resolve(path), :bytes, 8.0/1024] }
            record rx_metric, bandwidth[rx_metric], :unit => :kbps
            record tx_metric, bandwidth[tx_metric], :unit => :kbps
            
            # calculate packet rate
            packets = lambda {|path| rate[resolve(path), :packets, 1] }
            record rx_metric, packets[rx_metric], :unit => :'packets/s'
            record tx_metric, packets[tx_metric], :unit => :'packets/s'
        end
    end
end

# interface link and address information
interfaces.each do |dev|
    run "/sbin/ip address show #{dev}" do
        match /^\d+: #{dev}: <.+> mtu (\d+)/, :measure => "system.net.#{dev}.link.mtu", :as => :to_i, :unit => :bytes
        match /^\s*link\/([\w.\/]+) ([0-9a-f:]+) brd ([0-9a-f:]+)/ do |m|
            measure "system.net.#{dev}.link.type",      m[1].to_s
            measure "system.net.#{dev}.link.address",   m[2].to_s
            measure "system.net.#{dev}.link.broadcast", m[3].to_s
        end
        match /^\s*inet ([\d.]+)\/(\d+) brd ([\d.]+) scope (\w+)/ do |m|
            measure "system.net.#{dev}.inet.address",   m[1].to_s
            measure "system.net.#{dev}.inet.mask",      m[2].to_i
            measure "system.net.#{dev}.inet.broadcast", m[3].to_s
            measure "system.net.#{dev}.inet.scope",     m[4].to_s
        end
        match /^\s*inet6 ([0-9a-f:]+)\/(\d+) scope (\w+)/ do |m|
            measure "system.net.#{dev}.inet6.address",  m[1].to_s
            measure "system.net.#{dev}.inet6.mask",     m[2].to_i
            measure "system.net.#{dev}.inet6.scope",    m[3].to_s
        end
    end
end

