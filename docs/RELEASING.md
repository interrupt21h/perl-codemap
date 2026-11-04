# Releasing Perl CodeMap

Repository: https://github.com/interrupt21h/perl-codemap

Live demonstration: https://interrupt21h.github.io/perl-codemap/

## Initial public release (0.3.0)

The initial workflow in `.github/workflows/release.yml` is deliberately scoped
to the first public release. When this workflow is added to the default
branch, GitHub Actions validates the version, installs PPI, runs the Perl and
JavaScript tests, runs MakeMaker distribution tests, checks the tarball's
contents, and generates its SHA-256 checksum. Only then does it create the
annotated `v0.3.0` tag on the tested commit and publish the GitHub release.

If an error occurs, inspect **Actions → Release v0.3.0**. The workflow can
be rerun with its manual **Run workflow** button on `main`. If a release
already exists, it refuses to overwrite it; if the tag points to a different
commit, it stops rather than retagging an immutable version.

Releases and assets: https://github.com/interrupt21h/perl-codemap/releases

## Subsequent releases

This one-off bootstrap workflow should be replaced with a reusable workflow
triggered by semantic version tags before publishing 0.3.1 or later.

1. Update `$Perl::CodeMap::VERSION`, `CHANGELOG.md`, and documentation.
2. Run `make test`, `make distcheck`, `make disttest`, and the browser tests
   on a clean checkout, including the PPI parser.
3. Run `make dist`, inspect the contents, and generate a SHA-256 checksum.
4. Tag a tested commit with an annotated `vX.Y.Z` tag; never move a
   published tag.
5. Upload the tarball and checksum to a GitHub Release with release notes.

The existing GitHub Pages workflow publishes only a synthetic example, not
real project source trees. Since reports can embed source code, never attach
proprietary reports to public releases.

## CPAN / PAUSE

A GitHub Release is not a CPAN publication. PAUSE requires a separate author
account and namespace/indexing checks; upload to CPAN only after a separate
review and explicit decision to publish there.
