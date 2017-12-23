Solanum
=======

[![Gem Version](https://badge.fury.io/rb/solanum.svg)](https://badge.fury.io/rb/solanum)

This gem provides a monitoring daemon which can be configured to collect data
from a variety of pluggable sources. The results can be printed to the console
or sent to a [Riemann](http://riemann.io/) server. This requires the
`riemann-client` gem to work.


## Metric Events

Solanum represents each measurement datapoint as an _event_. Each event must
have at minimum a `service` and `metric` with the measurement name and value,
respectively. Events may also contain other attributes such as a `state`, `ttl`,
`tags`, and so on - see the [Riemann concepts](http://riemann.io/concepts.html)
page for more details.

```ruby
{
  service: 'cpu usage',
  metric: 0.1875,
  state: 'ok',
}
```


## Configuration

Solanum is configured using one or more YAML files. These specify common event
attributes, sources, and outputs.

See the [example config](config.yml) in this repo for possible config options.

### Defaults

The `defaults` section of the config provides common attributes to apply to
every event. This can be used to provide a common TTL, tags, and more.

### Sources

A _source_ is a class which extends `Solanum::Source` and implements the
`collect!` method to return metric events. Solanum comes with several metric
sources built in, including basic host-level monitoring of CPU usage, load,
memory, diskstats, network, and more.

Additional custom sources can be provided, as long as they are in Ruby's lib
path for the daemon.

### Outputs

An _output_ is a destination to report the collected events to. The simplest
one is the `print` output, which writes each event to STDOUT. This is useful for
debugging, but you probably won't leave it on for deployed daemons.

The other included choice is the `riemann` output, which sends each event to a
Riemann monitoring server.


## License

This is free and unencumbered software released into the public domain.
See the UNLICENSE file for more information.
