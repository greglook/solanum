Output Configuration
====================

Solanum ships with two outputs, a local printer and a Riemann recorder.


## print

The `print` output requires no configuration - it simply writes every event it
sees to the process's STDOUT stream. This is useful for debugging or if you want
a copy of the recorded events in a log file for some reason.


## riemann

The `riemann` output sends events to a [Riemann](http://riemann.io/) server for
processing. This is the main use-case for Solanum and it is usually deployed
with only the riemann output enabled. There are two options available:

- `host` (default: `localhost`)
  The output sends events to this host name.
- `port` (default: `5555`)
  This controls the TCP port that the output will connect to on the host.
