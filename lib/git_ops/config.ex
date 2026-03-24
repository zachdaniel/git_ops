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
    if !mix_project().project()[:version] do
      raise "mix_project must be configured in order to use git_ops. Please see the configuration in the README.md for an example."
    end

    changelog_path = Path.expand(changelog_file())

    if !(opts[:initial] || File.exists?(changelog_path)) do
      raise "\nFile: #{changelog_path} did not exist. Please use the `--initial` command to initialize."
    end
  end

  def mix_project, do: Application.get_env(:git_ops, :mix_project)
  def changelog_file, do: Application.get_env(:git_ops, :changelog_file) || "CHANGELOG.md"
  def repository_url, do: Application.get_env(:git_ops, :repository_url)
  def repository_path, do: Application.get_env(:git_ops, :repository_path) || File.cwd!()
  def manage_mix_version?, do: truthy?(Application.get_env(:git_ops, :manage_mix_version?))

  @doc """
  Returns whether GitHub integrations are enabled.

  When enabled, the system will attempt to find GitHub usernames for commit authors and pull request information.
  When disabled or if lookup fails, it will use the author's name directly.
  """
  def github_handle_lookup?, do: truthy?(Application.get_env(:git_ops, :github_handle_lookup?))

  @doc """
  Returns the base URL for the GitHub API. Override this if you are using a self-hosted GitHub instance.
  """
  def github_api_base_url,
    do: Application.get_env(:git_ops, :github_api_base_url) || "https://api.github.com"

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

  def type_keys do
    types()
    |> Map.keys()
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.join(" ")
  end

  def allowed_tags, do: :git_ops |> Application.get_env(:tags, []) |> Keyword.get(:allowed, :any)

  def allow_untagged?,
    do: :git_ops |> Application.get_env(:tags, []) |> Keyword.get(:allow_untagged?, true)

  def prefix, do: Application.get_env(:git_ops, :version_tag_prefix) || ""

  def managed_files do
    explicit = Application.get_env(:git_ops, :managed_files, [])

    mix_version_files =
      if manage_mix_version?() do
        source = mix_project().module_info()[:compile][:source] |> to_string()
        [{source, :mix}]
      else
        []
      end

    readme_files =
      case manage_readme_version() do
        false ->
          []

        readme_config ->
          readme_config
          |> List.wrap()
          |> Enum.map(fn
            {_path, _replace, _pattern} = tuple -> tuple
            path when is_binary(path) -> {path, :string}
          end)
      end

    (mix_version_files ++ readme_files ++ explicit)
    |> Enum.map(&desugar_managed_file/1)
  end

  defp desugar_managed_file({path, :mix}) do
    {path, fn v -> "@version \"#{v}\"" end, fn v -> "@version \"#{v}\"" end}
  end

  defp desugar_managed_file({path, :string}) do
    {path, fn v -> ", \"~> #{v}\"" end, fn v -> ", \"~> #{v}\"" end}
  end

  defp desugar_managed_file({_path, replace, pattern} = tuple)
       when is_function(replace, 1) and is_function(pattern, 1) do
    tuple
  end

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(_), do: true
end
