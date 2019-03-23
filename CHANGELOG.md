Change Log
==========

All notable changes to this project will be documented in this file, which
follows the conventions of [keepachangelog.com](http://keepachangelog.com/).
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

### Added
- Solanum will accept directory paths as command-line arguments and expand them
  to load all contained `*.yml` and `*.yaml` files.
  [#11](//github.com/greglook/solanum/issues/11)
- New `shell` source allows for arbitrary command execution to produce metrics
  in a flexible manner.
  [#13](//github.com/greglook/solanum/issues/13)

## [3.1.2] - 2018-12-11

### Fixed
- `process` source on linux correctly handles leading spaces when process ids
  are padded by `ps`. Owning user names are now expanded to 32 characters as
  well.

## [3.1.1] - 2018-11-15

### Fixed
- Properly trim version string on Linux platforms.
- Automatically reconnect Riemann client on send.

### Added
- The `disk-space` source now supports `usage-states` thresholds.
- Documented all source and output configuration options.

### Changed
- OS mode detection is now performed once at startup, and unsupported sources
  are omitted from the config with a warning. Sources can specify a `mode` in
  config to override the detected type.

## [3.1.0] - 2018-11-05

### Added
- New HTTP source allows for checking URL endpoints and asserting that the
  response meets certain properties.

## [3.0.0] - 2018-10-27

Clojure rewrite.

## 2.0.0 - 2018-02-18

Final cut of Ruby version.

[Unreleased]: https://github.com/greglook/solanum/compare/3.1.2...HEAD
[3.1.2]: https://github.com/greglook/solanum/compare/3.1.1...3.1.2
[3.1.1]: https://github.com/greglook/solanum/compare/3.1.0...3.1.1
[3.1.0]: https://github.com/greglook/solanum/compare/3.0.0...3.1.0
[3.0.0]: https://github.com/greglook/solanum/compare/2.0.0...3.0.0
