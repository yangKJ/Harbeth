# Changelog

Harbeth 的公开变更从本文件建立后开始记录，格式遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。这里只记录库使用者升级后需要知道的公开能力、行为、兼容性和重要修复，不复制内部提交历史。

## [Unreleased]

### Added

- Added an `ImageNode` masked-effect composite entry point that reuses the same pixel-exact primitive as local edit recipes.
- Added angular, diamond, reflected, band, ring, and multi-stop mask gradient primitives with deterministic graph fingerprints.
- Added pressure-aware open brush masks, luminance/color range masks, generic texture-channel mask sources, and single-channel mask storage formats.
- Added compiled derived-mask graphs for threshold, grow/shrink, edge bands, distance fields, edge-aware feathering, cleanup, and decontamination, with cancellation, caching, GPU analysis, and dirty bounds.
- Added compiled composite-mask batches that preserve ordered add, subtract, intersect, XOR, inversion, opacity, and feather semantics while processing up to four mask layers per GPU pass.

[Unreleased]: https://github.com/yangKJ/Harbeth/compare/2.0.1...HEAD
