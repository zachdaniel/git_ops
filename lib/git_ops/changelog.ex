defmodule GitOps.Changelog do
  def write(path, commits) do
    stream = File.stream!(path)

    stream =
      path
      |> File.stream!()
      |> Stream.drop_while(&Kernel.!=(&1, "<!-- changelog -->"))

    commits
    |> Enum.group_by(&Map.get(&1, :type))
    |> Stream.reject(fn {group, commits} ->
      group not in ["fix", "feat"]
    end)
    |> Stream.map(fn {group, commits} ->
      formatted_commits = Enum.map_join(commits, "\n", &GitOps.Commit.format/1)

      "#{group}:\n\n" <> formatted_commits
    end)
    |> Stream.into(stream)
    |> Stream.run()
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
end
