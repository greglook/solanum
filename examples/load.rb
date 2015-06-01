# Solanum monitoring configuration for cpu utilization metrics.

read "/proc/uptime" do
  match /^(\d+\.\d+)/, cast: :to_f, record: 'uptime'
end

read "/proc/loadavg" do
  match /^(\d+\.\d+) \d+\.\d+ \d+\.\d+ (\d+)\/(\d+) \d+$/ do |m, metrics|
    metrics['process load']    = m[1].to_f
    metrics['process running'] = m[2].to_i
    metrics['process count']   = m[3].to_i
  end
end
