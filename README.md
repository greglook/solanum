Solanum
=======

This gem provides a domain-specific language (DSL) for collecting metrics
data in Ruby. The `solanum` script takes a number of monitoring configuration
scripts as arguments and periodically collects the metrics defined. The results
can be printed to the console or sent to a [Riemann](http://riemann.io/) server.
This requires the `riemann-client` gem to work.

## Structure

Solanum scripts define _sources_, which provide some string input when they are
read. This input is processed by a set of _matchers_ for each source, which can
generate named measurements from that data. A simple example would be a file
source, which is read and matched line-by-line against a set of regular
expressions.

The emitted measurements can undergo a bit more processing before being
reported. For example, some metrics are monotonically-increasing counters, and
what we actually want is the _difference_ between each reading. For others, we
may want to apply threshold-based states to the events. These are set by
_service prototypes_, which are also defined in the scripts.

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

See the files in the `examples` directory for more monitor configuration samples.

## License

This is free and unencumbered software released into the public domain.
See the UNLICENSE file for more information.
