# Monorepos

git_ops releases any number of packages from one repository. Each package
gets its own version stream (tagged `<name>-vX.Y.Z`), its own changelog, and
its own release cadence, while one `mix git_ops.release` run handles them
all. No mix project is required, so the packages can be anything — Elixir,
node, terraform, a directory of YAML.

## Configuration

Monorepo configuration lives in a `git_ops.json` file at the repository
root, which takes precedence over the application environment:

```json
{
  "repository_url": "https://github.com/my_org/my_repo",
  "first_parent": true,
  "packages": {
    "my_app": {
      "managed_files": [{ "path": "mix.exs", "type": "mix" }]
    },
    "web": {
      "managed_files": [{ "path": "package.json", "type": "json" }],
      "exclude_paths": ["docs"],
      "patch_on_any_change": true
    },
    "web/shared": {
      "managed_files": [{ "path": "package.json", "type": "json" }]
    },
    "infra": {
      "managed_files": [{ "path": "version.txt", "type": "raw" }]
    }
  },
  "linked_packages": [["web", "web/shared"]]
}
```

Each key in `packages` is a directory. A commit belongs to the deepest
package whose directory contains it — a commit touching only `web/shared`
releases `web/shared`, not `web`.

`depends_on` declares shared code a package ships without containing: a
package with `"depends_on": ["libs/ui"]` is released by commits to
`libs/ui`, with those commits' changelog entries appearing in (and their
types driving the bump of) every package that declares them.

Per-package options:

| option | default | meaning |
|---|---|---|
| `name` | the directory basename | display name and tag component |
| `version_tag_prefix` | `<name>-v` | tag prefix for this package |
| `changelog_file` | `<path>/CHANGELOG.md` | created on first release if missing |
| `version_source` | `"tags"` | where the current version is read from |
| `managed_files` | `[]` | files updated with the new version on release |
| `exclude_paths` | `[]` | package-relative paths whose commits don't count |
| `depends_on` | `[]` | repo-relative paths whose commits also count — shared code the package ships |
| `patch_on_any_change` | `false` | release a patch for any conventional commit, not only fixes/features/breaking changes |
| `pr_group` | none | pull-request grouping (see below) |

`managed_files` entries take a `type` — `"mix"` (`@version "..."`), `"json"`
(a `"version": "..."` field), `"raw"` (the file's whole content is the
version), or `"string"` (`, "~> ..."`) — or a custom `"pattern"` template in
which `{version}` is replaced.

Top-level options: `repository_url`, `types` (changelog sections, e.g.
`{"chore": {"header": "Chores", "hidden": false}}`), `section_order`
(changelog section order by type; defaults to features first, fixes next,
chores last), `first_parent` (count only first-parent commits, for
squash/merge workflows), `linked_packages` (groups that always release
together at the same version), `release_strategy` and `pr_labels` (see
below).

## Releasing

By default `mix git_ops.release` releases every package with releasable
commits in one commit on the current branch, with one tag per released
package — the single-package flow, applied per package.

### Through pull requests

`"release_strategy": "pull_request"` splits releasing into two idempotent
phases, designed to run in CI on every push to the main branch:

1. `mix git_ops.release` computes pending releases, builds the changelog
   and version-file updates into a commit using git plumbing (the working
   tree is never touched), force-pushes a `git-ops/release/<name>` branch,
   and opens or updates its pull request. Packages sharing a `pr_group`
   share one branch and PR; every other package gets its own. `pr_labels`
   are applied when a PR is first created.
2. Merging a release PR *is* the release. `mix git_ops.tag_merged` then
   reconciles tags: any package whose version file holds a version with no
   matching tag gets tagged at the commit that set it, the tag is pushed,
   and a GitHub release is created from the changelog entry. The commit
   that set the version must match `tag_merged_commit_pattern` (default
   `^chore(\(.+\))?: release`), so a stray version-file edit in an ordinary
   commit is refused loudly instead of becoming a release.

Both tasks derive everything from repository state, so a run that dies
partway is repaired by the next one. GitHub API calls authenticate with the
`GITHUB_TOKEN` environment variable; pushes use the ambient git credentials.
Use a token whose pushes trigger workflows (a PAT or app token — in GitHub
Actions, pushes made with the default `GITHUB_TOKEN` don't) if tags are what
trigger your deploys.

### Running without a host project

git_ops can't be a mix archive (archives can't have dependencies), so a
repository with no mix project runs it through `Mix.install`:

```elixir
# scripts/release.exs
Mix.install([{:git_ops, "~> 2.10"}])

case System.argv() do
  ["tag_merged" | args] -> Mix.Tasks.GitOps.TagMerged.run(args)
  args -> Mix.Tasks.GitOps.Release.run(args)
end
```

A CI job then checks out with full history (`fetch-depth: 0`; a
`filter: blob:none` partial clone works — file contents are read through
`git show`), configures the bot's git identity, and runs
`elixir scripts/release.exs tag_merged` followed by
`elixir scripts/release.exs`.

## Trying it out

`--dry-run` never pushes or calls the GitHub API. With `--output <dir>` it
writes each would-be pull request's body and full file contents under the
directory, so you can inspect exactly what a config change does to the
release plan:

```sh
mix git_ops.release --dry-run --output /tmp/proposals
mix git_ops.tag_merged --dry-run
```

## Bootstrapping a package

A package's version history starts from its tags, so a package that has
never been released needs one baseline tag:

```sh
git tag my_app-v1.0.0 <sha>
```

Place it on the commit you consider already-released: commits after it feed
the first release PR, so tagging deep in history changelogs everything since.
