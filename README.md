Solanum
=======

[![CircleCI](https://circleci.com/gh/greglook/solanum.svg?style=shield&circle-token=c14a7265562fdec8881672070d87d812f076bf8a)](https://circleci.com/gh/greglook/solanum)
<img align="right" src="doc/logo.png">

Solanum is a simple monitoring daemon which can be configured to collect
host-level data from a variety of sources. The results can be printed to the
console or sent to a [Riemann](http://riemann.io/) server. This is primarily
intended as a replacement for running a number of independent programs like the
[riemann-tools](https://github.com/riemann/riemann-tools) daemons.

Solanum is written in Clojure and uses [Graal](https://www.graalvm.org/) to
compile native binaries. These are much simpler to deploy than coordinating Ruby
gem installs.


## Installation

Releases are published on the [GitHub project](https://github.com/greglook/solanum/releases).
The native binaries are self-contained, so to install them simply place them on
your path.


## Metric Events

Solanum represents each measurement datapoint as an _event_. Each event must
have at minimum a `service` and `metric` with the measurement name and value,
respectively. Events may also contain other attributes such as a `state`, `ttl`,
`tags`, and so on - see the [Riemann concepts](http://riemann.io/concepts.html)
page for more details.

```clojure
{:service "cpu usage"
 :metric 0.1875
 :state :ok}
```


## Configuration

Solanum is configured using one or more YAML files. These specify common event
attributes, sources, and outputs. Config files are provided as command-line
arguments, and merged together in order to collect the configured sources and
outputs.

See the [example config](config.yml) in this repo for possible config options.

### Defaults

The `defaults` section of the config provides common attributes to apply to
every event. This can be used to provide a common TTL, tags, and more.

**Note:** attributes specified on the command line take precedence over these
global defaults. In particular, this means that a custom hostname _must_ be set
on the command line to take effect.

### Sources

A _source_ is a record which implements a `collect-events` method to return
metric events. Solanum comes with several metric sources built in, including
basic host-level monitoring of CPU usage, load, memory, diskstats, network, and
more. You can provide your own custom sources, but you'll need to build your own
uberjar using this project as a dependency.

See the [source docs](doc/sources.md) for information about the available
source types and their configuration options.

### Outputs

An _output_ is a destination to report the collected events to. The simplest
one is the `print` output, which writes each event to STDOUT. This is useful for
debugging, but you probably won't leave it on for deployed daemons.

See the [output docs](doc/outputs.md) for information about the available output
types and their configuration options.


## License

This is free and unencumbered software released into the public domain.
See the UNLICENSE file for more information.
