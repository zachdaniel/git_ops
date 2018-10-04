defmodule GitOps.Changelog do
  def write(path, commits, last_version) do
    current_version = determine_new_version(last_version, commits)
    original_file_contents = File.read!(path)

    [head | rest] = String.split(original_file_contents, "<!-- changelog -->")

    config_types = GitOps.Config.types()

    breaking_changes = Enum.filter(commits, &breaking?/1)

    breaking_changes_contents =
      if Enum.empty?(breaking_changes) do
        []
      else
        [
          "### Breaking Changes:\n\n",
          Enum.map_join(breaking_changes, "\n\n", &GitOps.Commit.format/1)
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
        formatted_commits = Enum.map_join(commits, "\n\n", &GitOps.Commit.format/1)

        ["### ", config_types[group][:header] || group, ":\n\n", formatted_commits]
      end)

    repository_url = GitOps.Config.repository_url()

    today = Date.utc_today()
    date = ["(", to_string(today.year), ?-, to_string(today.month), ?-, to_string(today.day), ")"]

    version_header =
      if repository_url do
        trimmed_url = String.trim_trailing(repository_url, "/")
        branch = GitOps.Config.primary_branch()
        compare_link = compare_link(trimmed_url, branch, last_version, current_version)

        ["## [", current_version, "](", compare_link, ") ", date]
      else
        ["## ", current_version, " ", date]
      end

    File.write!(
      path,
      [
        head,
        "\n",
        version_header,
        "\n\n\n",
        breaking_changes_contents,
        "\n\n",
        contents_to_insert,
        rest
      ]
    )
  end

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
  end

  defp determine_new_version(old_version, commits) do
    parsed = Version.parse!(old_version)

    new_version =
      cond do
        Enum.any?(commits, &breaking?/1) ->
          # major
          %{parsed | major: parsed.major + 1, minor: 0, patch: 0, pre: [], build: nil}

        Enum.any?(commits, &feature?/1) ->
          %{parsed | minor: parsed.minor + 1, patch: 0, pre: [], build: nil}

        Enum.any?(commits, &fix?/1) ->
          %{parsed | patch: parsed.patch + 1, pre: [], build: nil}

        true ->
          parsed
      end

    to_string(new_version)
  end

  defp breaking?(%GitOps.Commit{breaking?: breaking?}), do: breaking?

  defp feature?(%GitOps.Commit{type: type}) do
    String.downcase(type) == "feat"
  end

  defp fix?(%GitOps.Commit{type: type}) do
    String.downcase(type) == "fix"
  end

  defp compare_link(url, branch, last_version, current_version) do
    [
      url,
      "/compare/",
      branch,
      "@",
      last_version,
      "...",
      branch,
      "@",
      current_version
    ]
  end
end
