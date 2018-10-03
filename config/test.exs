use Mix.Config

config :git_ops,
  changelog_file: "CHANGELOG.md",
  additional_types: [:special_type, :special_type2],
  scopes: [:config, :tasks]
