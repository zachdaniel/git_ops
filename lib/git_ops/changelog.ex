defmodule GitOps.Changelog do
  @moduledoc """
  Functions for writing commits to the changelog, and initializing it.
  """

  alias GitOps.Commit
  alias GitOps.Config

  @spec write(String.t(), [Commit.t()], String.t(), String.t(), Keyword.t()) :: String.t()
  def write(path, commits, last_version, current_version, opts \\ []) do
    original_file_contents = File.read!(path)

    {new_contents, entry} =
      render(original_file_contents, commits, last_version, current_version, opts)

    if !opts[:dry_run] do
      File.write!(path, new_contents)
    end

    entry
  end

  @doc """
  The updated changelog contents and the new entry, without touching the
  filesystem.
  """
  @spec render(String.t(), [Commit.t()], String.t(), String.t(), Keyword.t()) ::
          {String.t(), String.t()}
  def render(original_file_contents, commits, last_version, current_version, opts \\ []) do
    {head, rest, insert_marker?} = split_at_insertion_point(original_file_contents)

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

    section_order = Config.section_order()
    section_rank = fn group -> Enum.find_index(section_order, &(&1 == group)) end

    contents_to_insert =
      commits
      |> Enum.reject(&Map.get(&1, :breaking?))
      |> Enum.group_by(fn commit ->
        String.downcase(commit.type)
      end)
      |> Enum.filter(fn {group, _commits} ->
        Map.has_key?(config_types, group) && !config_types[group][:hidden?]
      end)
      |> Enum.sort_by(fn {group, _commits} ->
        {section_rank.(group) || length(section_order), group}
      end)
      |> Enum.map(fn {group, commits} ->
        formatted_commits = Enum.map_join(commits, "\n\n", &Commit.format/1)

        ["\n\n### ", config_types[group][:header] || group, ":\n\n", formatted_commits]
      end)

    repository_url = Config.repository_url()

    today = Date.utc_today()
    date = ["(", Date.to_iso8601(today), ")"]

    version_header =
      if repository_url do
        trimmed_url = String.trim_trailing(repository_url, "/")
        prefix = opts[:prefix] || Config.prefix()
        compare_link = compare_link(trimmed_url, prefix, last_version, current_version)

        ["## [", current_version, "](", compare_link, ") ", date]
      else
        ["## ", current_version, " ", date]
      end

    new_message =
      IO.iodata_to_binary([
        version_header,
        "\n",
        breaking_changes_contents,
        "\n\n",
        contents_to_insert
      ])

    separator = if insert_marker?, do: "\n\n<!-- changelog -->\n\n", else: "\n\n"

    new_contents =
      IO.iodata_to_binary([
        String.trim(head),
        separator,
        new_message,
        rest
      ])

    {new_contents, String.trim(new_message)}
  end

  @spec initial_contents() :: String.t()
  def initial_contents do
    String.trim_leading("""
    # Change Log

    All notable changes to this project will be documented in this file.
    See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

    <!-- changelog -->
    """)
  end

  @spec initialize(String.t(), Keyword.t()) :: :ok
  def initialize(path, opts \\ []) do
    if File.exists?(path) do
      raise "\nFile already exists: #{path}. Please remove it to initialize."
    end

    if !opts[:dry_run] do
      File.write!(path, initial_contents())
    end

    :ok
  end

  # Without a `<!-- changelog -->` marker, insert before the first version
  # header so changelogs that predate git_ops keep their entries in order.
  defp split_at_insertion_point(contents) do
    case String.split(contents, "<!-- changelog -->") do
      [_] ->
        case Regex.run(~r/^#+ \[?v?\d/m, contents, return: :index) do
          [{index, _}] ->
            {binary_part(contents, 0, index),
             ["\n\n", binary_part(contents, index, byte_size(contents) - index)], false}

          nil ->
            {contents, "", false}
        end

      [head | rest] ->
        {head, rest, true}
    end
  end

  defp compare_link(url, prefix, last_version, current_version) do
    [
      url,
      "/compare/",
      prefixed(prefix, last_version),
      "...",
      prefixed(prefix, current_version)
    ]
  end

  defp prefixed(prefix, version) do
    if String.starts_with?(version, prefix), do: version, else: prefix <> version
  end
end
