# Solanum monitoring configuration for system memory usage metrics.
# 
# Author:: Greg Look

# memory usage
read "/proc/meminfo" do
  match /^MemTotal:\s+(\d+) kB$/,  :record => "system.memory.total",   :as => :to_i, :unit => :kB
  match /^MemFree:\s+(\d+) kB$/,   :record => "system.memory.free",  :as => :to_i, :unit => :kB
  match /^Buffers:\s+(\d+) kB$/,   :record => "system.memory.buffers", :as => :to_i, :unit => :kB
  match /^Cached:\s+(\d+) kB$/,  :record => "system.memory.cached",  :as => :to_i, :unit => :kB
  
  match /^SwapTotal:\s+(\d+) kB$/, :record => "system.swap.total",   :as => :to_i, :unit => :kB
  match /^SwapFree:\s+(\d+) kB$/,  :record => "system.swap.free",    :as => :to_i, :unit => :kB
end

# calculate percentages from total space
compute do
  [%w{system.memory free buffers cached},
   %w{system.swap   free}].each do |info|
    parent = info.shift
    total = get_metric("#{parent}.total").value :kB
    next unless total && total > 0
    info.each_with_index do |name, i|
      metric = get_metric "#{parent}.#{name}"
      used = metric.value :kB
      metric.record 100.0*used/total, :% if used
    end
  end
end
