defmodule GitOps.Config do
  def mix_project(), do: Application.get_env(:git_ops, :mix_project)
  def changelog_file(), do: Application.get_env(:git_ops, :changelog_file) || "CHANGELOG.md"
  def repository_url(), do: Application.get_env(:git_ops, :repository_url)
  def manage_mix_version?(), do: truthy?(Application.get_env(:git_ops, :manage_mix_version?))

  def manage_readme_version() do
    case Application.get_env(:git_ops, :manage_readme_version) do
      true ->
        "README.md"

      file when is_bitstring(file) ->
        file

      other ->
        truthy?(other)
    end
  end

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

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(_), do: true
end
