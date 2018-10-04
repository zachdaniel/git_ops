# GitOps

A small tool to help generate changelogs from conventional commit messages.
For more information, see [conventional
commits](https://conventionalcommits.org).
For an example, see this project's [CHANGELOG.md](CHANGELOG.md).

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
    {:git_ops, "~> 0.1.0"}
  ]
end
```
Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/git_ops](https://hexdocs.pm/git_ops).

