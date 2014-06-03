# Solanum

This is an experiment in writing a domain-specific language (DSL) for collecting
metrics data in Ruby. The `solanum` script takes a number of configuration files
as arguments and collects the metrics defined by those files. The results are
printed and optionally, stored as a local YAML file.

## Examples

Here's an example of reading some information about the current system process
load:

```ruby
read "/proc/loadavg" do
  match /^(\d+\.\d+) \d+\.\d+ \d+\.\d+ (\d+)\/(\d+) \d+$/ do |m|
    record "system.process.load",  m[1].to_f
    record "system.process.running", m[2].to_i
    record "system.process.count",   m[3].to_i
  end
end
```

Data sources can also be output from commands, and metrics can be generated
directly - for example, to calculate percentages or rates from previously
recorded metrics. See the files in the `etc` directory for more examples.

## License

This is free and unencumbered software released into the public domain.
See the UNLICENSE file for more information.
