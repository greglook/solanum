# Solanum monitoring configuration for disk utilization metrics.

# detect disk devices to monitor
disks = Dir['/dev/*'].grep(/^\/dev\/[hs]d[a-z]/){|dev| dev[5..7] }.uniq.sort
puts "Detected disk devices: #{disks.join}" unless disks.empty?

# SMART health
# disks.each do |dev|
#   run "/usr/sbin/smartctl -HA /dev/#{dev}" do
#     match /^SMART overall\-health self\-assessment test result: (\w+)$/, record: "disk #{dev} smart"
#     match /^\s*9\s+Power_On_Hours\s+0x\d+\s+\d+\s+\d+\s+\d+\s+\w+\s+\w+\s+\S+\s+(\d+)$/, cast: :to_i, record: "disk #{dev} age"
#     match /^\s*194\s+Temperature_Celsius\s+0x\d+\s+\d+\s+\d+\s+\d+\s+\w+\s+\w+\s+\-\s+(\d+)$/, cast: :to_i, record: "disk #{dev} temp"
#   end
# end

# disk utilization
read "/proc/diskstats" do
  disks.each do |dev|
    match /^\s*\d+\s+\d+\s+#{dev}\s+\d+\s+\d+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+(\d+)\s+\d+\s+\d+\s+\d+\s+\d+$/ do |m, metrics|
      # calculate io utilization from the cumulative 512B sector count
      # since system boot
      %w{read write}.each_with_index do |name, i|
        metrics["disk #{dev} io #{name} bytes"] = 512*m[i+1].to_i
      end
    end
  end
end unless disks.empty?

service /^disk \S+ io \w+ bytes$/, diff: true
