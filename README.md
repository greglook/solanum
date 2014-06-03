Solanum
=======

This library provides a domain-specific language (DSL) for collecting metrics
data in Ruby. The `solanum` script takes a number of monitoring configuration
scripts as arguments and periodically collects the metrics defined. The results
are printed to the console.

The `riemann-solanum` script is similar, except it reports the collected data
to a [Riemann](http://riemann.io/) server. This requires the `riemann-client`
gem.

## Examples

Here's an example of reading some information about the current system memory:

```ruby
# Read memory usage.
read "/proc/meminfo" do
  match /^MemTotal:\s+(\d+) kB$/, cast: :to_i, scale: 1024, record: 'memory total bytes'
  match /^MemFree:\s+(\d+) kB$/,  cast: :to_i, scale: 1024, record: 'memory free bytes'
end

# Calculate percentages from total space.
compute do |metrics|
  total = metrics['memory total bytes']
  free = metrics['memory free bytes']
  if total && free
    metrics['memory free pct'] = free.to_f/total
  end
end

# Define a service prototype with a threshold-based state.
service 'memory free pct', state: thresholds(0.00, :critical, 0.10, :warning, 0.25, :ok)
```

See the files in the `monitors` directory for more examples.

## License

This is free and unencumbered software released into the public domain.
See the UNLICENSE file for more information.
