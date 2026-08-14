defmodule GitOps.Package do
  @moduledoc """
  A releasable package within the repository.

  Repositories configured through the application environment, or through a
  `git_ops.json` without a `packages` map, have exactly one package rooted at
  the repository itself. A `packages` map defines one entry per released
  directory, each with its own tag prefix, changelog, and managed files.
  """

  defstruct [
    :path,
    :name,
    :prefix,
    :changelog_file,
    :version_source,
    :pr_group,
    :version_file,
    managed_files: [],
    exclude_paths: [],
    depends_on: [],
    patch_on_any_change?: false,
    solo_pr?: false,
    root?: false
  ]

  @type version_source :: :mix | :tags | {:file, String.t(), Regex.t()}

  @type t :: %__MODULE__{
          path: String.t(),
          name: String.t() | nil,
          prefix: String.t(),
          changelog_file: String.t(),
          version_source: version_source(),
          pr_group: String.t() | nil,
          version_file: {String.t(), Regex.t()} | nil,
          managed_files: [{String.t(), (String.t() -> String.t()), (String.t() -> String.t())}],
          exclude_paths: [String.t()],
          depends_on: [String.t()],
          patch_on_any_change?: boolean(),
          solo_pr?: boolean(),
          root?: boolean()
        }
end
