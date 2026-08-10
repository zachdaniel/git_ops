defmodule GitOps.Config do
  @moduledoc """
  Helpers around fetching configurations, including setting defaults.

  Configuration is resolved from a `git_ops.json` file at the repository root
  when one exists, falling back to the application environment otherwise. The
  file form is required for multi-package (monorepo) repositories and supports
  releasing projects that have no mix project at all.
  """

  alias GitOps.Package

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
    if file_config() == nil do
      if version_source() == :mix && !mix_project().project()[:version] do
        raise "mix_project must be configured in order to use git_ops. Please see the configuration in the README.md for an example."
      end

      changelog_path = Path.expand(changelog_file())

      if !(opts[:initial] || File.exists?(changelog_path)) do
        raise "\nFile: #{changelog_path} did not exist. Please use the `--initial` command to initialize."
      end
    end
  end

  def mix_project, do: Application.get_env(:git_ops, :mix_project)

  @doc """
  The path of the JSON config file, relative to the repository root.

  When the file exists it takes precedence over the application environment.
  """
  def config_file, do: Application.get_env(:git_ops, :config_file) || "git_ops.json"

  @doc false
  def file_config do
    case Process.get(__MODULE__) do
      nil ->
        config =
          case File.read(Path.join(repository_path(), config_file())) do
            {:ok, contents} -> Jason.decode!(contents)
            _ -> :none
          end

        Process.put(__MODULE__, config)
        file_config()

      :none ->
        nil

      config ->
        config
    end
  end

  @doc false
  def reload_file_config, do: Process.delete(__MODULE__)

  defp file_get(key), do: (file_config() || %{})[key]

  @doc """
  The packages this repository releases.

  A `packages` map in the config file produces one entry per package.
  Otherwise there is a single package rooted at the repository, configured
  from the file's top level or from the application environment.
  """
  def packages do
    case file_get("packages") do
      packages when is_map(packages) and map_size(packages) > 0 ->
        packages
        |> Enum.sort_by(fn {path, _} -> path end)
        |> Enum.map(fn {path, package_config} -> build_package(path, package_config) end)

      _ ->
        version_source = version_source()

        version_file =
          case version_source do
            {:file, path, regex} -> {path, regex}
            _ -> derive_version_file(file_config() || %{}, ".")
          end

        [
          %Package{
            path: ".",
            name: file_get("name"),
            prefix: prefix(),
            changelog_file: changelog_file(),
            version_source: version_source,
            version_file: version_file,
            managed_files: managed_files(),
            exclude_paths: file_get("exclude_paths") || [],
            patch_on_any_change?: file_get("patch_on_any_change") || false,
            root?: true
          }
        ]
    end
  end

  defp build_package(path, config) do
    name = config["name"] || Path.basename(path)

    %Package{
      path: path,
      name: name,
      prefix: config["version_tag_prefix"] || "#{name}-v",
      changelog_file: config["changelog_file"] || Path.join(path, "CHANGELOG.md"),
      version_source: parse_version_source(config["version_source"], path) || :tags,
      pr_group: config["pr_group"],
      version_file: derive_version_file(config, path),
      managed_files: parse_managed_files(config["managed_files"], path),
      exclude_paths: Enum.map(config["exclude_paths"] || [], &Path.join(path, &1)),
      depends_on: config["depends_on"] || [],
      patch_on_any_change?: config["patch_on_any_change"] || false
    }
  end

  # Where tag_merged reads a package's released version: the file version
  # source, or the first managed file whose version can be extracted back out.
  defp derive_version_file(config, base) do
    case parse_version_source(config["version_source"], base) do
      {:file, path, regex} ->
        {path, regex}

      _ ->
        Enum.find_value(config["managed_files"] || [], fn
          %{"path" => path, "type" => "json"} ->
            {join_base(base, path), ~r/"version":\s*"([^"]+)"/}

          %{"path" => path, "type" => "mix"} ->
            {join_base(base, path), ~r/@version "([^"]+)"/}

          %{"path" => path, "type" => "raw"} ->
            {join_base(base, path), ~r/\A\s*(\S+)/}

          %{"path" => path, "pattern" => template} ->
            {join_base(base, path), template_regex(template)}

          _ ->
            nil
        end)
    end
  end

  defp template_regex(template) do
    template
    |> Regex.escape()
    |> String.replace("\\{version\\}", ~S/([^\s"']+)/)
    |> Regex.compile!()
  end

  defp parse_version_source(nil, _base), do: nil
  defp parse_version_source("tags", _base), do: :tags
  defp parse_version_source("mix", _base), do: :mix

  defp parse_version_source(%{"file" => file, "pattern" => pattern}, base) do
    {:file, join_base(base, file), Regex.compile!(pattern)}
  end

  defp parse_managed_files(nil, _base), do: []

  defp parse_managed_files(managed_files, base) do
    Enum.map(managed_files, fn
      %{"path" => path, "type" => type} when type in ["mix", "string", "json", "raw"] ->
        desugar_managed_file({join_base(base, path), String.to_existing_atom(type)})

      %{"path" => path, "pattern" => pattern} ->
        replace = fn version -> String.replace(pattern, "{version}", version) end
        {join_base(base, path), replace, replace}
    end)
  end

  defp join_base(".", path), do: path
  defp join_base(base, path), do: Path.join(base, path)

  @doc "Whether commit collection follows only the first parent of merges."
  def first_parent?, do: file_get("first_parent") || false

  @doc """
  How releases are performed.

  * `:commit` (default) - commit and tag directly on the current branch.
  * `:pull_request` - push a release branch and open a pull request; tags are
    created after the pull request merges, by `mix git_ops.tag_merged`.
  """
  def release_strategy do
    case file_get("release_strategy") || Application.get_env(:git_ops, :release_strategy) ||
           :commit do
      value when value in ["commit", :commit] -> :commit
      value when value in ["pull_request", :pull_request] -> :pull_request
    end
  end

  @doc """
  Groups of package paths whose versions move in lockstep: when any package
  in a group releases, every package in that group releases at that version.
  """
  def linked_packages, do: file_get("linked_packages") || []

  @doc "Labels applied to release pull requests when they are created."
  def pr_labels, do: file_get("pr_labels") || []

  @doc """
  The pattern a version-bump commit must match for `mix git_ops.tag_merged`
  to tag it. Guards against a stray version-file edit in an ordinary commit
  becoming a release.
  """
  def tag_merged_commit_pattern do
    case file_get("tag_merged_commit_pattern") do
      nil -> ~r/^chore(\(.+\))?: release/
      pattern -> Regex.compile!(pattern)
    end
  end

  @doc """
  Where the current version is read from.

  * `:mix` (default) - the configured `mix_project`'s `:version`.
  * `:tags` - the last valid version tag (respecting `version_tag_prefix`),
    making tags the source of record. Requires no mix project, so this
    enables releasing non-Elixir projects.
  * `{:file, path, regex}` - the first capture group of `regex` run against
    the contents of `path`.
  """
  def version_source do
    cond do
      source = parse_version_source(file_get("version_source"), ".") -> source
      file_config() -> :tags
      true -> Application.get_env(:git_ops, :version_source) || :mix
    end
  end

  def changelog_file do
    file_get("changelog_file") || Application.get_env(:git_ops, :changelog_file) ||
      "CHANGELOG.md"
  end

  def repository_url,
    do: file_get("repository_url") || Application.get_env(:git_ops, :repository_url)

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
    configured = file_types() || Application.get_env(:git_ops, :types) || []

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

  defp file_types do
    case file_get("types") do
      types when is_map(types) ->
        Enum.map(types, fn {type, config} ->
          {String.to_atom(String.downcase(type)),
           Enum.reject(
             [header: config["header"], hidden?: config["hidden"]],
             fn {_, value} -> is_nil(value) end
           )}
        end)

      _ ->
        nil
    end
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

  def prefix do
    file_get("version_tag_prefix") || Application.get_env(:git_ops, :version_tag_prefix) || ""
  end

  def managed_files do
    if file_config() do
      parse_managed_files(file_get("managed_files"), ".")
    else
      app_env_managed_files()
    end
  end

  defp app_env_managed_files do
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

  defp desugar_managed_file({path, :json}) do
    {path, fn v -> "\"version\": \"#{v}\"" end, fn v -> "\"version\": \"#{v}\"" end}
  end

  defp desugar_managed_file({path, :raw}) do
    {path, fn v -> v end, fn v -> v end}
  end

  defp desugar_managed_file({_path, replace, pattern} = tuple)
       when is_function(replace, 1) and is_function(pattern, 1) do
    tuple
  end

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(_), do: true
end
