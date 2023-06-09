defmodule GitOps.Config do
  @moduledoc """
  Helpers around fetching configurations, including setting defaults.
  """

  @default_types [
    build: [
      hidden?: true
    ],
    chore: [
      hidden?: true
    ],
    ci: [
      hidden?: true
    ],
    docs: [
      hidden?: true
    ],
    feat: [
      header: "Features",
      hidden?: false
    ],
    fix: [
      header: "Bug Fixes",
      hidden?: false
    ],
    improvement: [
      header: "Improvements",
      hidden?: false
    ],
    perf: [
      header: "Performance Improvements",
      hidden?: false
    ],
    refactor: [
      hidden?: true
    ],
    style: [
      hidden?: true
    ],
    test: [
      hidden?: true
    ]
  ]

  def mix_project_check(opts \\ []) do
    unless mix_project().project()[:version] do
      raise "mix_project must be configured in order to use git_ops. Please see the configuration in the README.md for an example."
    end

    changelog_path = Path.expand(changelog_file())

    unless opts[:initial] || File.exists?(changelog_path) do
      raise "\nFile: #{changelog_path} did not exist. Please use the `--initial` command to initialize."
    end
  end

  def mix_project, do: Application.get_env(:git_ops, :mix_project)
  def changelog_file, do: Application.get_env(:git_ops, :changelog_file) || "CHANGELOG.md"
  def repository_url, do: Application.get_env(:git_ops, :repository_url)
  def repository_path, do: Application.get_env(:git_ops, :repository_path) || File.cwd!()
  def manage_mix_version?, do: truthy?(Application.get_env(:git_ops, :manage_mix_version?))

  def manage_readme_version do
    case Application.get_env(:git_ops, :manage_readme_version) do
      true ->
        "README.md"

      nil ->
        false

      other ->
        other
    end
  end

  def types do
    configured = Application.get_env(:git_ops, :types) || []

    @default_types
    |> Keyword.merge(configured)
    |> Enum.into(%{}, fn {key, value} ->
      sanitized_key =
        key
        |> to_string()
        |> String.downcase()

      {sanitized_key, value}
    end)
  end

  def allowed_tags, do: :git_ops |> Application.get_env(:tags, []) |> Keyword.get(:allowed, :any)

  def allow_untagged?,
    do: :git_ops |> Application.get_env(:tags, []) |> Keyword.get(:allow_untagged?, true)

  def prefix, do: Application.get_env(:git_ops, :version_tag_prefix) || ""

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(_), do: true
end
