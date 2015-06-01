# Solanum monitoring configuration for cpu utilization metrics.

read "/proc/cpuinfo" do
  match /^cpu MHz\s*:\s+(\d+\.\d+)/, cast: :to_f, record: 'cpu frequency'
end

read "/proc/stat" do
  match /^cpu(\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+) (\d+)/ do |m, metrics|
    core = m[1].to_i

    # calculate cpu utilization from the cumulative time spent in
    # 'jiffies' (1/100 sec) since system boot
    %w{user nice system idle iowait irqhard irqsoft}.each_with_index do |name, i|
      metrics["cpu core#{core} #{name} jiffies"] = m[i+2].to_i
    end
  end
end

service /^cpu core\d+ \w+ jiffies$/, diff: true
