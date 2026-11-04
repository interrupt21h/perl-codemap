# Publishing Perl CodeMap to a public Git repository

This source distribution was prepared to be imported into a repository, but
publishing is deliberately a separate, owner-controlled step.

## Before making it public

Confirm the Git repository contains **only code you are authorized to share**.
The included `examples/sample/`, `examples/demo.html`, and
`docs/assets/example-map.png` are generated from synthetic code. Do not add
reports made from employer, customer, or other private source trees.

Review staged changes:

```sh
git status --short
git diff --cached --stat
git diff --cached --name-only
```

Check the archive for accidentally staged reports, local credentials,
internal domain names, absolute file paths and API tokens. Excluding
`*.html` globally is not necessary: the included HTML demo is synthetic.

## Initialize and push

```sh
cd perl-codemap

git init -b main
git add .
git diff --cached --stat
git commit -m "Initial public release: Perl CodeMap 0.3.0"

# Create a new, empty repository on your preferred Git host.
# Example using GitHub CLI (requires you to sign in first):
gh repo create perl-codemap --public --source=. --remote=origin --push
```

If the host's user interface creates the remote, instead use `git remote add
origin <your-new-repository-url>` followed by `git push -u origin main`.

## Repository metadata suggestions

**Description:** Interactive architecture and source-code maps for Perl
applications — static analysis, dependency graphs, and offline source browsing.

**Topics:** `perl`, `static-analysis`, `dependency-graph`, `code-visualization`,
`ppi`, `software-architecture`, `code-browser`.

**License:** MIT. **Issue tracker:** enabled. **Security reporting:** enable
private vulnerability reports and add a maintainer contact address to
`SECURITY.md`. **Actions:** enable CI after reviewing its permissions.

## Tag and release

Run `prove -Ilib t`, `node t/browser-smoke.js`, and `make test` before a
release. Set an immutable version tag:

```sh
git tag -a v0.3.0 -m "Perl CodeMap 0.3.0"
git push origin v0.3.0
```

Attach an archive of the tagged public source distribution to the release. Do
not attach `code-map.json` or reports generated from real private code.

## Publishing the interactive sample with GitHub Pages

The existing `.github/workflows/ci.yml` includes `build-pages` and
`deploy-pages` jobs. On a successful push to `main`, they generate
`_site/index.html` from the **synthetic** files under `examples/sample/`,
then deploy that one-page site using the official GitHub Pages actions.

Enable **Settings → Pages → Build and deployment → Source: GitHub Actions**
once after creating the repository. No `gh-pages` branch, personal access
token, stored credential, or custom domain is needed.

The workflow will not deploy from pull requests or feature branches.
See [GITHUB_PAGES.md](GITHUB_PAGES.md) for details and security notes.

