# GitOps

A small tool to help generate changelogs from conventional commit messages.
For more information, see [conventional
commits](https://conventionalcommits.org).
For an example, see this project's [CHANGELOG.md](CHANGELOG.md).

Roadmap (in no particular order):

* Automatically update mix.exs and the descriptive line in the readme
* Support pre releases, release candidates, and build information
* A hundred other things I forgot to write down while writing the initial version
* Automatically parse issue numbers and github mentions into the correct format,
  linking the issue
* A task to build a compliant commit
* Release to hex, with task documentation

Important addendums:

A new version of the spec in beta adds a rather useful
convention. Add ! in front of a commit message to simply signal it as a breaking
change, instead of adding `BREAKING CHANGE: description` in your commit message.
For example: `!fix(Spline Reticulator): `

The spec doesn't specify behavior around multiple scopes. This library parses
scopes *as a comma separated list*. This allows for easily readable multiple
word lists `feat(Something Special, Something Else Special): message`. Keep in
mind that you are very limited on space in these messages, and if you find
yourself using multiple scopes your commit is probably too big.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `git_ops` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:git_ops, "~> 0.2.0", only: [:dev]}
  ]
end
```

## Configuration

``` elixir
config :git_ops,
  mix_project: MyApp.MixProject,
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/my_user/my_repo",
  primary_branch: "master",
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
  # Instructs the tool to manage your mix version in your `mix.exs` file
  # See below for more information
  manage_mix_version?: true,
  # Instructs the tool to manage the version in your README.md
  # Pass in `true` to use `"README.md"` or a string to customize
  manage_readme_version: "README.md"
```

Package is not yet released on hex, but when it is documentation will be found there.

Getting started:

```bash
mix git_ops.release --initial
```

Commit the result of that, using a message like `chore: Initial Release`

Then when you want to release again, use:

``` bash
mix git_ops.release
```

## Managing your mix version

To have mix manage your mix version, add `manage_mix_version?: true` to your configuration.

Then, use a module attribute called `@version` to manage your application's
version. Look at [this project's mix.exs](mix.exs) for an example.

## Managing your readme version

Most project readmes have a line like this that would ideally remain up to date:

```elixir
    {:git_ops, "~> 0.2.0", only: [:dev]}
```

You can keep that number up to date via `manage_readme_version`, which accepts
`true` for `README.md` or a string pointing to some other path relative to your
project root.



