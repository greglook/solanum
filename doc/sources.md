Source Configuration
====================

Solanum has a number of metrics sources which can be used for local monitoring.
All sources support the following configuration parameters:

- `type`
  This is required for every source.
- `mode`
  May be provided to override the _mode_ the source operates in, which is
  typically a specific system type like `linux`, `darwin`, `bsd`, etc.
- `period` (default: `60`)
  The scheduler will collect metrics from the source every time this duration in
  seconds passes, plus a bit of jitter.
- `attributes`
  May be provided as a nested map of attributes to add to each event from this
  source. These take precedence over any defaults in the config or attributes
  provided on the command-line.


## cpu

The `cpu` source measures processor utilization across the entire machine. It
may also provide per-core and per-state measurements if more detailed resolution
is desired. The main event reported is `cpu usage` with the value as the
percentage of time the cpu spent working.

- `per-core`
  If true, the source will report events with the usage of each core in addition
  to full-cpu usage. These events will have a `core` attribute with the measured
  core number.
- `per-state`
  If true, the source will report events with the percentage of time the cpu
  spent in each state, such as `user`, `nice`, `system`, `iowait`, `idle`, etc.
  Can be combined with `per-core` to show per-core-states.
- `usage-states`
  A map of state names to thresholds. If the value in a usage event meets or
  exceeds the value of a threshold, the event's `state` will be set to match.


## disk-space

The `disk-space` source measures filesystem space usage. It reports a
`disk space usage` event for each mounted filesystem that appears to correspond
to a block device which gives the percentage of space being used.

- `usage-states`
  A map of state names to thresholds. If the value in a usage event meets or
  exceeds the value of a threshold, the event's `state` will be set to match.


## disk-stats

The `disk-stats` source measures block device IO utilization. It reports a
collection of metrics including the number of bytes read and written, the time
spent on those operations, and overall IO activity.

- `devices`
  A list of block devices to measure. By default the source will measure any
  devices matching `sd[a-z]` or `xvd[a-z]`.
- `detailed`
  If true, the source will report several additional IO metrics such as counts
  of the read and write requests which have completed or been merged.


## http

**WARNING:** Currently non-functional in native binaries - see
[#8](https://github.com/greglook/solanum/issues/8).

...


## load

...


## memory

...


## network

...


## process

...


## tcp

...


## test

...


## uptime

...
