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

The `http` source makes requests to a local HTTP endpoint and validates
properties about the response. This is useful for triggering health-check
APIs and verifying that services are running properly. The source produces two
events, `http url time` and `http url health`.

- `url` (required)
  The URL to call. This _should_ be a local service running on the host, but is
  not forced to be.
- `label` (default: same as `url`)
  Overrides the `label` field in the sent events with a more human-friendly
  name. Usually this is set to the name of the service being checked.
- `timeout` (default: `1000`)
  How many milliseconds to wait for a response before an error is returned.
- `response-checks`
  A sequence of validations to run against the HTTP response. By default, this
  just asserts that the response code was `200`. See the
  [response checks](#http-response-checks) section below.
- `record-fields`
  A map of event attributes to data paths to forward in each event. For example,
  an entry of `foo: bar` would set the event attribute `foo` to the value of
  `bar` in the response body. This may also be nested, so `foo: [bar, qux]`
  would look up the value of `qux` inside the map at `bar` in the response.

### HTTP Response Checks

Each response check defines a rule used to determine whether the HTTP endpoint
is healthy or not. Checks may be one of three types:

- `status`
  This check evaluates whether the HTTP response code matches a set of
  acceptable values. A single code may be given as a `value` or a list may be
  provided as `values`.
- `pattern`
  This check matches a regular expression in `pattern` against the _text body_
  of the response. If the expression matches, the check passes.
- `data`
  This check tries to parse the response body as EDN or JSON and determines
  whether a value inside the response matches a set of acceptable values. The
  value is resolved by looking up the check `key` using the `record-fields`
  logic above, then checked against `value` or `values` in the check. If the
  value is not acceptable or the body cannot be parsed, the check fails.


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
