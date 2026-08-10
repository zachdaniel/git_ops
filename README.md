# GitOps

[![Hex pm](http://img.shields.io/hexpm/v/git_ops.svg?style=flat)](https://hex.pm/packages/git_ops)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/git_ops/)
[![Total Download](https://img.shields.io/hexpm/dt/git_ops.svg)](https://hex.pm/packages/git_ops)
[![License](https://img.shields.io/hexpm/l/git_ops.svg)](https://github.com/zachdaniel/git_ops/blob/master/LICENSE)

A small tool to help generate changelogs from conventional commit messages.
For more information, see [conventional
commits](https://conventionalcommits.org).
For an example, see this project's [CHANGELOG.md](https://github.com/zachdaniel/git_ops/blob/master/CHANGELOG.md).

Roadmap (in no particular order):

- More tests
- Automatically parse issue numbers and github mentions into the correct format, linking the issue
- A task to build a compliant commit
- Validation of commits
- A hundred other things I forgot to write down while writing the initial version

Important addendums:

A new version of the spec in beta adds a rather useful
convention. Add ! after the type/scope to simply signal it as a breaking
change, instead of adding `BREAKING CHANGE: description` in your commit message.
For example: `fix(Spline Reticulator)!: `

The spec doesn't specify behavior around multiple scopes. This library parses
scopes _as a comma separated list_. This allows for easily readable multiple
word lists `feat(Something Special, Something Else Special): message`. Keep in
mind that you are very limited on space in these messages, and if you find
yourself using multiple scopes your commit is probably too big.

## Installation with Igniter

If `Igniter` is not already in your project, add it to your deps:

```elixir
def deps do
  [
    {:igniter, "~> 0.5", only: [:dev, :test]}
  ]
end
```

Then, run the installer:

```sh
mix igniter.install git_ops
```

## Manual Installation

```elixir
def deps do
  [
    {:git_ops, "~> 2.6.1", only: [:dev]}
  ]
end
```

## Configuration

```elixir
config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  
  # if set to true, this uses git user.email to lookup user on github and insert the handle in release notes
  # otherwise it uses the author name as provided in the commit
  github_handle_lookup?: true,
  github_api_base_url: "https://api.github.com",
  
  repository_url: "https://github.com/my_user/my_repo",
  types: [
    # Makes an allowed commit type called `tidbit` that is not
    # shown in the changelog
    tidbit: [
      hidden?: true
    ],
    # Makes an allowed commit type called `important` that gets
    # a section in the changelog with the header "Important Changes"
    important: [
      header: "Important Changes"
    ]
  ],
  tags: [
    # Only add commits to the changelog that has the "backend" tag
    allowed: ["backend"],
    # Filter out or not commits that don't contain tags
    allow_untagged?: true
  ],
  # Instructs the tool to manage your mix version in your `mix.exs` file
  # See below for more information
  manage_mix_version?: true,
  # Instructs the tool to manage the version in your README.md
  # Pass in `true` to use `"README.md"` or a string to customize
  manage_readme_version: "README.md",
  # Manage an arbitrary list of files during release.
  # See "Managing additional files" below for details.
  managed_files: [
    {"apps/my_app/mix.exs", :mix},
    {"README.md", :string}
  ],
  version_tag_prefix: "v",
  # Where the current version is read from:
  # :mix (default) reads the configured mix_project's version,
  # :tags reads the last valid version tag, and
  # {:file, path, regex} reads the regex's first capture group from path.
  # :tags and {:file, ...} need no mix project, enabling non-Elixir projects.
  version_source: :mix
```

## Configuration with `git_ops.json`

A `git_ops.json` file at the repository root takes precedence over the
application environment, and is how repositories without a mix project — or
with more than one package — configure git_ops. With a config file the
current version is read from tags by default (`version_source: "tags"`), so
no mix project is required.

```json
{
  "repository_url": "https://github.com/my_user/my_repo",
  "types": {"docs": {"hidden": true}, "important": {"header": "Important Changes"}},
  "version_tag_prefix": "v",
  "managed_files": [{"path": "package.json", "type": "json"}]
}
```

`managed_files` entries take a `type` (`"mix"`, `"json"` for a
`"version": "..."` field, `"raw"` for a file whose whole content is the
version, or `"string"`) or a custom `"pattern"` template in which
`{version}` is replaced.

### Monorepos

A `packages` map releases each package independently: commits are attributed
to the deepest package whose path contains them, each package gets its own
`<name>-v`-prefixed tags and its own `CHANGELOG.md`, and one
`mix git_ops.release` run releases everything that changed, as one commit
with one tag per released package.

```json
{
  "repository_url": "https://github.com/my_user/my_repo",
  "first_parent": true,
  "packages": {
    "my_app": {"managed_files": [{"path": "mix.exs", "type": "mix"}]},
    "web": {
      "managed_files": [{"path": "package.json", "type": "json"}],
      "exclude_paths": ["docs"],
      "patch_on_any_change": true
    },
    "web/shared": {"managed_files": [{"path": "package.json", "type": "json"}]}
  },
  "linked_packages": [["web", "web/shared"]]
}
```

Per-package options: `name` (defaults to the directory basename),
`version_tag_prefix` (defaults to `<name>-v`), `changelog_file`,
`version_source`, `managed_files` (paths are package-relative),
`exclude_paths` (package-relative paths whose commits don't count),
`patch_on_any_change` (release a patch for any conventional commit, not just
fixes and features), and `pr_group` (see below). `linked_packages` groups
always release together at the same version. `first_parent` restricts commit
collection to the first parent of merges, so only merge/squash commits on
the branch itself count.

### Releasing through pull requests

`"release_strategy": "pull_request"` turns `mix git_ops.release` into a
proposal step: instead of committing and tagging, it pushes a
`git-ops/release/<name>` branch containing the changelog and version-file
updates (the working tree is never touched) and opens or updates a pull
request, authenticated by the `GITHUB_TOKEN` environment variable. Packages
sharing a `pr_group` share one branch and pull request; every other package
gets its own. A top-level `pr_labels` list is applied to each pull request
when it is first created.

Merging a release pull request is the release. `mix git_ops.tag_merged` —
run on every push to the base branch — reconciles the rest: any package
whose version file holds a version with no matching tag gets tagged at the
commit that set it, the tag is pushed, and a GitHub release is created from
its changelog entry. Both tasks are idempotent, so a run that dies partway
is repaired by the next one.

`mix git_ops.release --dry-run --output some/dir` writes each would-be pull
request's body and file contents under `some/dir` without pushing anything —
useful for reviewing what a config change does to the release plan.

Getting started:

```bash
mix git_ops.release --initial
```

Commit the result of that, using a message like `chore: Initial Release`

Then when you want to release again, use:

```bash
mix git_ops.release
```

For the full documentation of that task, see the task documentation in hex.

## Managing your mix version

To have mix manage your mix version, add `manage_mix_version?: true` to your configuration.

Then, use a module attribute called `@version` to manage your application's
version. Look at [this project's mix.exs](mix.exs) for an example.

## Managing your readme version

Most project readmes have a line like this that would ideally remain up to date:

```elixir
    {:git_ops, "~> 2.6.1", only: [:dev]}
```

You can keep that number up to date via `manage_readme_version`, which accepts
`true` for `README.md` or a string pointing to some other path relative to your
project root.

## Managing additional files

For projects that need to update version strings in multiple files (e.g. poncho
apps with several `mix.exs` files), use the `managed_files` option:

```elixir
config :git_ops,
  managed_files: [
    {"apps/my_app/mix.exs", :mix},
    {"apps/my_other_app/mix.exs", :mix},
    {"README.md", :string},
    {"package.json", fn v -> "\"version\": \"#{v}\"" end, fn v -> "\"version\": \"#{v}\"" end}
  ]
```

Each entry is a tuple describing a file and how to find/replace the version
string within it:

- `{path, :mix}` — replaces `@version "x.y.z"` (same pattern as `manage_mix_version?`)
- `{path, :string}` — replaces `"~> x.y.z"` (same pattern as `manage_readme_version`)
- `{path, replace_fn, pattern_fn}` — custom functions that each take a version
  string and return the text to find/replace

The `managed_files` list is merged with any files contributed by
`manage_mix_version?` and `manage_readme_version`, so you can use all three
options together or migrate to `managed_files` entirely.

## Using this with open source projects

If you'd like your contributors to use the conventional commit format, you can
use a PULL_REQUEST_TEMPLATE.md like the one in our repo. However,
it is also possible to manage it as the maintainers of a project by altering
either the merge commit or alter the commit when merging/squashing (recommended)

## Similar projects

- https://github.com/glasnoster/eliver
- https://github.com/oo6/mix-bump
- https://github.com/mpanarin/versioce
