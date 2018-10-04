defmodule GitOps.Changelog do
  def write(path, commits, last_version, current_version) do
    original_file_contents = File.read!(path)

    [head | rest] = String.split(original_file_contents, "<!-- changelog -->")

    config_types = GitOps.Config.types()

    breaking_changes = Enum.filter(commits, &GitOps.Commit.breaking?/1)

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
        "\n\n<!-- changelog -->\n\n",
        version_header,
        "\n",
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
