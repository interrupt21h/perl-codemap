# Publishing Perl CodeMap

**Maintainer:** Scott Muller <scott@21h.io>.

- Public repository: https://github.com/interrupt21h/perl-codemap/
- Live sample: https://interrupt21h.github.io/perl-codemap/
- GitHub releases: https://github.com/interrupt21h/perl-codemap/releases

The repository is already public and its initial v0.3.0 release was published
on GitHub. For new versions, follow [RELEASING.md](RELEASING.md), rather than
reinitializing the repository or rerunning the original bootstrap procedure.

## Before publishing

Confirm changes and release artifacts contain only code you are authorized to
share. The tracked `examples/sample/`, `examples/demo.html`, and
`docs/assets/example-map.png` are synthetic. Generated reports may embed
complete source files and must not be published if they contain proprietary
code, secrets, or personal information.

```sh
git status --short
git diff --stat
git grep -n -E 'PASSWORD|TOKEN|PRIVATE_KEY' -- . ':!docs/PUBLISHING.md'
```

The quick text search is illustrative; use a dedicated secret-scanning tool
for a real security review.

## Repository metadata

**Name:** `interrupt21h/perl-codemap`.

**Maintainer:** Scott Muller <scott@21h.io>.

**Description:** Interactive code maps for Perl projects. Visualize package
dependencies, explore modules and subroutines, and browse syntax-highlighted
source code.

**Topics:** `perl`, `static-analysis`, `dependency-graph`,
`code-visualization`, `ppi`, `software-architecture`, `code-browser`.

**License:** MIT; original Go CodeMap and PrismJS retain their respective
third-party notices in `NOTICE.md` and the Prism license.

## Releasing

The GitHub **Release** workflow uses `$Perl::CodeMap::VERSION` and validates
the matching version tag; it produces the distribution tarball and a SHA-256
checksum. Do not overwrite an existing version or force-move a published tag.
The workflow can be started through **Actions → Release → Run workflow** after
the version and changelog are committed to `main`.

Do not publish a GitHub release archive to PAUSE automatically. A CPAN upload
requires PAUSE credentials and separate verification; see
[RELEASING.md](RELEASING.md).

## GitHub Pages

The existing CI workflow deploys a synthetic demo from `examples/sample/`
to [https://interrupt21h.github.io/perl-codemap/](https://interrupt21h.github.io/perl-codemap/)
on successful pushes to `main`. It publishes only `_site` and never scans
employer or customer source trees. See [GITHUB_PAGES.md](GITHUB_PAGES.md).
