defmodule GitOps.Config do
  def mix_project(), do: Application.get_env(:git_ops, :mix_project)
  def changelog_file(), do: Application.get_env(:git_ops, :changelog_file) || "CHANGELOG.md"
  def repository_url(), do: Application.get_env(:git_ops, :repository_url)
  def primary_branch(), do: Application.get_env(:git_ops, :primary_branch) || "master"

  def types() do
    configured = Application.get_env(:git_ops, :types) || []

    default = [
      feat: [
        header: "Features",
        hidden?: false
      ],
      fix: [
        header: "Bug Fixes",
        hidden?: false
      ],
      chore: [
        hidden?: true
      ],
      docs: [
        hidden?: true
      ],
      test: [
        hidden?: true
      ]
    ]

    default
    |> Keyword.merge(configured)
    |> Enum.into(%{}, fn {key, value} ->
      sanitized_key =
        key
        |> to_string()
        |> String.downcase()

      {sanitized_key, value}
    end)
  end
end
