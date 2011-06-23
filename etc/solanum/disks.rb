# Solanum monitoring configuration for disk utilization metrics.
# 
# Author:: Greg Look

# detect disk devices to monitor
disks = Dir['/dev/*'].grep(/^\/dev\/[hs]d[a-z]/){|dev| dev[5..7] }.uniq.sort
puts "Detected disk devices: #{disks.join}" unless disks.empty?

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
        metric.record_rate :kBps, m[i+1].to_i, :sectors
      end
    end
  end
end unless disks.empty?
