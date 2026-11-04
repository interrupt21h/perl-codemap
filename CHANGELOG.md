# Changelog

All notable changes to this project will be documented here. Versioning follows
[Semantic Versioning](https://semver.org/).

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

- This is an initial **public-ready source package**, not an assertion that it
  has been published to any public repository or CPAN.
- PPI-based parsing is recommended; the lite mode is explicitly heuristic.
