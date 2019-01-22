defmodule GitOps.Changelog do
  @moduledoc """
  Functions for writing commits to the changelog, and initializing it.
  """

  alias GitOps.Commit
  alias GitOps.Config

  @spec write(String.t(), [Commit.t()], String.t(), String.t(), Keyword.t()) :: String.t()
  def write(path, commits, last_version, current_version, opts \\ []) do
    original_file_contents = File.read!(path)

    [head | rest] = String.split(original_file_contents, "<!-- changelog -->")

    config_types = Config.types()

    breaking_changes = Enum.filter(commits, &Commit.breaking?/1)

    breaking_changes_contents =
      if Enum.empty?(breaking_changes) do
        []
      else
        [
          "### Breaking Changes:\n\n",
          Enum.map_join(breaking_changes, "\n\n", &Commit.format/1)
        ]
      end

    contents_to_insert =
      commits
      |> Enum.reject(&Map.get(&1, :breaking?))
      |> Enum.group_by(fn commit ->
        String.downcase(commit.type)
      end)
      |> Stream.filter(fn {group, _commits} ->
        Map.has_key?(config_types, group) && !config_types[group][:hidden?]
      end)
      |> Enum.map(fn {group, commits} ->
        formatted_commits = Enum.map_join(commits, "\n\n", &Commit.format/1)

        ["\n\n### ", config_types[group][:header] || group, ":\n\n", formatted_commits]
      end)

    repository_url = Config.repository_url()

    today = Date.utc_today()
    date = ["(", to_string(today.year), ?-, to_string(today.month), ?-, to_string(today.day), ")"]

    version_header =
      if repository_url do
        trimmed_url = String.trim_trailing(repository_url, "/")
        compare_link = compare_link(trimmed_url, last_version, current_version)

        ["## [", current_version, "](", compare_link, ") ", date]
      else
        ["## ", current_version, " ", date]
      end

    new_contents =
      IO.iodata_to_binary([
        String.trim(head),
        "\n\n<!-- changelog -->\n\n",
        version_header,
        "\n",
        breaking_changes_contents,
        "\n\n",
        contents_to_insert,
        rest
      ])

    unless opts[:dry_run] do
      File.write!(path, new_contents)
    end

    String.trim(original_file_contents, new_contents)
  end

  @spec initialize(String.t()) :: :ok
  def initialize(path) do
    contents = """
    # Change Log

    All notable changes to this project will be documented in this file.
    See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

    <!-- changelog -->
    """

    if File.exists?(path) do
      raise "\nFile already exists: #{path}. Please remove it to initialize."
    end

    File.write!(path, String.trim_leading(contents))

    :ok
  end

  defp compare_link(url, last_version, current_version) do
    [
      url,
      "/compare/",
      last_version,
      "...",
      current_version
    ]
  end
end
