Solanum
=======

This gem provides a simple daemon which can be configured to run a number of
checks and report metrics from their outcomes. The results can be printed to the
console or sent to a [Riemann](http://riemann.io/) server. This requires the
`riemann-client` gem to work.

## Structure

In Solanum, the daemon runs _sources_, which may produce events for reporting.
Sources are configured using a simple YAML format.

## License

This is free and unencumbered software released into the public domain.
See the UNLICENSE file for more information.
