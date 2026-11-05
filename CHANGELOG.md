# Changelog

All notable changes to this project will be documented here. Versioning follows
[Semantic Versioning](https://semver.org/).

## [0.3.1] - 2026-11-05

### Changed

- Set distribution author and public maintainer to Scott Muller <scott@21h.io>.
- Update MIT copyright ownership and project-wide author attribution while
  preserving Peter Retief's and PrismJS's original third-party credits.
- Add maintainer contact and vulnerability reporting instructions.
- Add author metadata checks for releases and generalize the GitHub Release
  workflow for future versioned distributions.
- Refresh release, publishing, and development documentation.

### Notes

- Maintenance/metadata release. No breaking public API changes.
- Published on GitHub and uploaded to CPAN by Scott Muller (PAUSE author
  `MULLER`) on 2026-11-05; the PAUSE namespace indexer successfully indexed
  `Perl::CodeMap`.

## [0.3.0] - 2026-11-04

### Added

- Standalone Perl distribution with standard `Makefile.PL` installation.
- CLI documentation, manpage-ready module POD, and versioned JSON export.
- Offline dependency graph with namespace drill-down and cycle handling.
- Syntax-highlighted source browser, file/line deep links, and optional remote
  repository source URLs.
- Source embedding/hydration with path traversal safeguards.
- Synthetic fixture, parser/CLI/HTML tests, frontend checks, and CI workflow.
- Public contribution, security, architecture, and release documentation.

### Notes

- Initial GitHub source release. CPAN publication was not part of this release.
- PPI-based parsing is recommended; the lite mode is explicitly heuristic.
