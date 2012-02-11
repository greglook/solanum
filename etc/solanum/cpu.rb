# Solanum monitoring configuration for cpu utilization metrics.
#
# Author:: Greg Look

# system uptime
read "/proc/uptime" do
  match /^(\d+\.\d+)/, :record => "system.uptime", :as => :to_f, :unit => :seconds
end

# system load
read "/proc/loadavg" do
  match /^(\d+\.\d+) \d+\.\d+ \d+\.\d+ (\d+)\/(\d+) \d+$/ do |m|
    record "system.process.load",  m[1].to_f
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
      metric.record_rate :%, m[i+2].to_i, :jiffies
    end
  end
end
