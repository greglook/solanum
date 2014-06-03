# Read memory usage.
read "/proc/meminfo" do
  match /^MemTotal:\s+(\d+) kB$/,     cast: :to_i, scale: 1024, record: "memory total bytes"
  match /^MemFree:\s+(\d+) kB$/,      cast: :to_i, scale: 1024, record: "memory free bytes"
  match /^MemAvailable:\s+(\d+) kB$/, cast: :to_i, scale: 1024, record: "memory available bytes"
  match /^Buffers:\s+(\d+) kB$/,      cast: :to_i, scale: 1024, record: "memory buffers bytes"
  match /^Cached:\s+(\d+) kB$/,       cast: :to_i, scale: 1024, record: "memory cached bytes"
  match /^Active:\s+(\d+) kB$/,       cast: :to_i, scale: 1024, record: "memory active bytes"
  match /^SwapTotal:\s+(\d+) kB$/,    cast: :to_i, scale: 1024, record: "swap total bytes"
  match /^SwapFree:\s+(\d+) kB$/,     cast: :to_i, scale: 1024, record: "swap free bytes"
end

# Calculate percentages from total space.
compute do |metrics|
  percentages = {
    "memory" => %w{free available buffers cached active},
    "swap"   => %w{free}
  }

  percentages.each do |sys, stats|
    total = metrics["#{sys} total bytes"]
    if total && total > 0
      stats.each do |stat|
        bytes = metrics["#{sys} #{stat} bytes"]
        if bytes
          pct = bytes.to_f/total
          metrics["#{sys} #{stat} pct"] = pct
        end
      end
    end
  end

  metrics
end

service "memory available pct", state: thresholds(0.00, :critical, 0.10, :warning, 0.25, :ok)
service "swap free pct",        state: thresholds(0.00, :critical, 0.10, :warning, 0.25, :ok)
