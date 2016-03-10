# Change Log

All notable changes to Radix project will be documented in this file.
This project aims to comply with [Semantic Versioning](http://semver.org/),
so please check *Changed* and *Removed* notes before upgrading.

## [0.1.2] - 2016-03-10
### Fixed
- No longer split named parameters that share same level (@alsm)

### Changed
- Attempt to use two named parameters at same level will display a
  deprecation warning. Future versions will raise `Radix::Tree::SharedKeyError`

## [0.1.1] - 2016-02-29
### Fixed
- Fix named parameter key names extraction.

## [0.1.0] - 2016-01-24
### Added
- Initial release based on code extracted from Beryl.

[Unreleased]: https://github.com/luislavena/radix/compare/v0.1.2...HEAD
[0.1.2]: https://github.com/luislavena/radix/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/luislavena/radix/compare/v0.1.0...v0.1.1
