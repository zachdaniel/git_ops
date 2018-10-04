defmodule Mix.Tasks.GitOps.Release do
  use Mix.Task

  @shortdoc "Parses the commit log and writes any updates to the changelog"

  @doc false
  def run(args) do
    changelog_file = Application.get_env(:git_ops, :changelog_file)
    path = Path.expand(changelog_file)
    mix_project_module = Application.get_env(:git_ops, :mix_project)
    mix_project = mix_project_module.project()
    repo = Git.init!(File.cwd!())

    current_version =
      if mix_project[:version] do
        String.trim(mix_project[:version])
      else
        raise """
        Unable to determine the version of your mix_project.

        Ensure your mix project is configured correctly, and has a version specified.
        """
      end

    opts = get_opts(args)

    if opts[:initial] do
      contents = """
      # Change Log

      All notable changes to this project will be documented in this file.
      See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.
      """

      if File.exists?(path) do
        raise "\nFile already exists: #{path}. Please remove it to initialize."
      end

      File.write!(path, String.trim_leading(contents))

      Git.tag(repo, current_version)
    end

    if not File.exists?(path) do
      raise "\nFile: #{path} did not exist. Please use the `--initial` command to initialize."
    end

    commits =
      if opts[:initial] do
        get_initial_commits!(repo)
      else
        get_commits_since_last_version!(repo)
      end

    IO.inspect(commits)

    ## Get the commit log since either the beginning of time, or the last tag that is a semver.
    ## use first_valid_version to get the most recent one (that isn't this one)

    :ok
  end

  def get_opts(args) do
    {opts, _} = OptionParser.parse!(args, strict: [initial: :boolean], aliases: [i: :initial])

    opts
  end

  defp get_initial_commits!(repo) do
    messages =
      repo
      |> Git.log!(["--format=%B"])
      |> String.split("\n")

    ["chore(GitOps): Add changelog using git_ops." | messages]
  end

  defp get_commits_since_last_version!(repo) do
    tags =
      repo
      |> Git.tag!()
      |> String.split("\n")

    if Enum.empty?(tags) do
      raise """
      Could not find an appropriate semver tag in git history. Ensure that you have initialized the project and commited the result.
      """
    end

    most_recent_tag = GitOps.Version.first_valid_version(tags)

    repo
    |> Git.log!(["#{most_recent_tag}..HEAD", "--format=%B"])
    |> IO.inspect()
    |> String.split("\n")
  end
end
