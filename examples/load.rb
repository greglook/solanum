# Solanum monitoring configuration for cpu utilization metrics.

read "/proc/uptime" do
  match /^(\d+\.\d+)/, cast: :to_f, record: 'uptime'
end

read "/proc/loadavg" do
  match /^(\d+\.\d+) \d+\.\d+ \d+\.\d+ (\d+)\/(\d+) \d+$/ do |matches|
    {
      'process load'    => matches[1].to_f,
      'process running' => matches[2].to_i,
      'process count'   => matches[3].to_i
    }
  end
end
