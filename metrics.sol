# Solanum monitoring configuration
# vim: ft=ruby


##### SYSTEM STATUS #####

# hardware sensor data
run "sensors" do
    match /^Core 0:\s+\+(\d+\.\d+)°C/, :record => "system.sensor.coretemp", :as => :to_f, :unit => :'°C'
    match /^temp1:\s+\+(\d+\.\d+)°C/,  :record => "system.sensor.temp1",    :as => :to_f, :unit => :'°C'
    match /^temp2:\s+\+(\d+\.\d+)°C/,  :record => "system.sensor.temp2",    :as => :to_f, :unit => :'°C'
    match /^temp3:\s+\+(\d+\.\d+)°C/,  :record => "system.sensor.temp3",    :as => :to_f, :unit => :'°C'
end

# system uptime
read "/proc/uptime" do
    match /^(\d+\.\d+)/, :measure => "system.uptime", :as => :to_f, :unit => :s
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
        match /^cpu#{i} (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) \d+ \d+$/ do |m|
            user_metric    = "system.cpu.core#{i}.user"
            nice_metric    = "system.cpu.core#{i}.nice"
            system_metric  = "system.cpu.core#{i}.system"
            idle_metric    = "system.cpu.core#{i}.idle"
            iowait_metric  = "system.cpu.core#{i}.iowait"
            irqhard_metric = "system.cpu.core#{i}.irqhard"
            irqsoft_metric = "system.cpu.core#{i}.irqsoft"
            
            # cumulative time spent in 'jiffies' (1/100 sec) since system boot
            record user_metric,    m[1].to_i, :unit => :jiffy
            record nice_metric,    m[2].to_i, :unit => :jiffy
            record system_metric,  m[3].to_i, :unit => :jiffy
            record idle_metric,    m[4].to_i, :unit => :jiffy
            record iowait_metric,  m[5].to_i, :unit => :jiffy
            record irqhard_metric, m[6].to_i, :unit => :jiffy
            record irqsoft_metric, m[7].to_i, :unit => :jiffy
            
            # calculate cpu utilization
            util = lambda do |metric|
                records = recall metric, :unit => :jiffy
                if records.length > 1
                    dv = records[0].value - records[1].value
                    dt = records[0].time - records[1].time
                    ( dv >= 0 ) ? dv/(100.0*dt) : nil
                else
                    nil
                end
            end
            
            # record avg cpu utilization
            record user_metric,    util[user_metric   ], :unit => :%
            record nice_metric,    util[nice_metric   ], :unit => :%
            record system_metric,  util[system_metric ], :unit => :%
            record idle_metric,    util[idle_metric   ], :unit => :%
            record iowait_metric,  util[iowait_metric ], :unit => :%
            record irqhard_metric, util[irqhard_metric], :unit => :%
            record irqsoft_metric, util[irqsoft_metric], :unit => :%
        end
    end
end

# memory utilization
read "/proc/meminfo" do
    match /^MemTotal:\s+(\d+) kB$/,  :record => "system.memory.total",   :as => :to_i, :unit => :kB
    match /^MemFree:\s+(\d+) kB$/,   :record => "system.memory.free",    :as => :to_i, :unit => :kB
    match /^Buffers:\s+(\d+) kB$/,   :record => "system.memory.buffers", :as => :to_i, :unit => :kB
    match /^Cached:\s+(\d+) kB$/,    :record => "system.memory.cached",  :as => :to_i, :unit => :kB
    match /^SwapTotal:\s+(\d+) kB$/, :record => "system.swap.total",     :as => :to_i, :unit => :kB
    match /^SwapFree:\s+(\d+) kB$/,  :record => "system.swap.free",      :as => :to_i, :unit => :kB
end



##### DISK INFORMATION #####

disks = ['sda']

# SMART health
disks.each do |dev|
    run "smartctl -HA /dev/#{dev}" do
        match /^SMART overall\-health self\-assessment test result: (\w+)$/, :measure => "system.disk.#{dev}.smart"
        match /^\s*9\s+Power_On_Hours\s+0x\d+\s+\d+\s+\d+\s+\d+\s+\w+\s+\w+\s+\S+\s+(\d+)$/, :measure => "system.disk.#{dev}.age", :as => :to_i, :unit => :hour
        match /^\s*194\s+Temperature_Celsius\s+0x\d+\s+\d+\s+\d+\s+\d+\s+\w+\s+\w+\s+\-\s+(\d+)$/, :record => "system.disk.#{dev}.temp", :as => :to_i, :unit => :'°C'
    end
end

# disk utilization
# cumulative 512B sectors since system boot
read "/proc/diskstats" do
    disks.each do |dev|
        match /^\s*\d+\s+\d+\s+#{dev}\s+\d+\s+\d+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+$/ do |m|
            record "system.disk.#{dev}.io.read",  m[1].to_i, :unit => :sector
            record "system.disk.#{dev}.io.write", m[2].to_i, :unit => :sector
        end
    end
end



##### NETWORK STATUS #####

interfaces = ['wan0', 'lan0', 'wlan0']

# network interface utilization
read "/proc/net/dev" do
    interfaces.each do |dev|
        match /^\s*#{dev}:\s*(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+$/ do |m|
            
            # cumulative since system boot
            record "system.net.#{dev}.io.rx", m[1].to_i, :unit => :B
            record "system.net.#{dev}.io.rx", m[2].to_i, :unit => :packet
            record "system.net.#{dev}.io.tx", m[3].to_i, :unit => :B
            record "system.net.#{dev}.io.tx", m[4].to_i, :unit => :packet
        end
    end
end

# interface link and address information
interfaces.each do |dev|
    run "ip address show #{dev}" do
        match /^\d+: #{dev}: <.+> mtu (\d+)/, :measure => "system.net.#{dev}.link.mtu", :as => :to_i, :unit => 'B'
        match /^\s*link\/([\w.\/]+) ([0-9a-f:]+) brd ([0-9a-f:]+)/ do |m|
            measure "system.net.#{dev}.link.type",      m[1].to_s
            measure "system.net.#{dev}.link.address",   m[2].to_s
            measure "system.net.#{dev}.link.broadcast", m[3].to_s
        end
        match /^\s*inet ([\d.]+)\/(\d+) brd ([\d.]+) scope (\w+)/ do |m|
            measure "system.net.#{dev}.inet.address",   m[1].to_s
            measure "system.net.#{dev}.inet.mask"       m[2].to_i
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

