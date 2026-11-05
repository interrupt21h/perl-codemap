# Releasing Perl CodeMap

**Author and maintainer:** Scott Muller <scott@21h.io>.

- Source: https://github.com/interrupt21h/perl-codemap
- Releases: https://github.com/interrupt21h/perl-codemap/releases
- Live sample: https://interrupt21h.github.io/perl-codemap/

## Versioning

Use semantic versions. The canonical software version is
`$Perl::CodeMap::VERSION` in `lib/Perl/CodeMap.pm`.
The distribution is `Perl-CodeMap-X.Y.Z.tar.gz`, the annotated tag is
`vX.Y.Z`, and the command is `perl-codemap`.

Bump the module version and update `CHANGELOG.md` for every new release.
Update the README when behavior, installation, or compatibility changes.
Never replace an existing GitHub release asset or move a published version tag.

## Validate a candidate

```sh
cpanm PPI
perl Makefile.PL
make
make test
node --check lib/Perl/CodeMap/assets/app.js
node t/browser-smoke.js
make distcheck
make disttest
```

The release workflow repeats these checks on GitHub Actions, including the
PPI parser, tests the dist tarball, verifies `META.json` author metadata, and
writes a SHA-256 checksum.

## Publish on GitHub

After committing version and documentation changes to `main`, open
**Actions → Release → Run workflow**, selecting `main`. The workflow:

1. Reads and validates the module version.
2. Refuses to overwrite an already published release.
3. Installs PPI and runs all Perl, JavaScript, and MakeMaker tests.
4. Builds and inspects the tarball, including author metadata and required assets.
5. Creates an annotated `vX.Y.Z` tag on the tested commit, or validates an
   existing tag points at that same commit.
6. Creates a published GitHub release with tarball, SHA-256 checksum, notes,
   and links to the live demo and maintainer.

The v0.3.1 maintenance release also runs automatically when the upgraded
release workflow first lands on `main`. Future releases should be initiated
deliberately with **Run workflow** after the version and changelog are updated.
A tag that points elsewhere causes a hard failure rather than being moved.

If a failure occurs, review the workflow logs. A partially successful attempt
may leave a tag but no published release; rerunning is safe **only when the tag
still points at the same tested commit**.

## CPAN / PAUSE

GitHub publication does not upload to CPAN. A separate PAUSE account,
namespace/indexing review, and manual archive upload are required.
The CPAN distribution metadata names Scott Muller <scott@21h.io> as author.

Keep PAUSE credentials out of the Git repository and never place them in a
public CI job. If PAUSE upload automation is later introduced, protect it with
a separate manually approved GitHub environment and upload the already-tested
release archive.

## Private source safety

The CLI can embed source contents in HTML and JSON. Do not include private
reports, credentials, or proprietary code in this public distribution or on
the public Pages demo.
