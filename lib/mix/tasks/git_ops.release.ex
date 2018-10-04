defmodule Mix.Tasks.GitOps.Release do
  use Mix.Task

  @shortdoc "Parses the commit log and writes any updates to the changelog"

  @doc false
  def run(args) do
    changelog_file = Application.get_env(:git_ops, :changelog_file)
    path = Path.expand(changelog_file)
    mix_project_module = Application.get_env(:git_ops, :mix_project)
    mix_project = mix_project_module.project()
    repo = GitOps.Git.init!()

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
      GitOps.Changelog.initialize(path)
      Git.tag(repo, current_version)
    end

    if not File.exists?(path) do
      raise "\nFile: #{path} did not exist. Please use the `--initial` command to initialize."
    end

    commit_messages =
      if opts[:initial] do
        GitOps.Git.get_initial_commits!(repo)
      else
        GitOps.Git.get_commits_since_last_version!(repo)
      end

    commit_messages
    |> Enum.map(fn commit ->
      case GitOps.Commit.parse(commit) do
        {:ok, commit} ->
          commit

        _ ->
          Mix.shell().error("Unparseable commit: #{commit}")
      end
    end)
    |> write_to_changelog(path)

    :ok
  end

  def get_opts(args) do
    {opts, _} = OptionParser.parse!(args, strict: [initial: :boolean], aliases: [i: :initial])

    opts
  end

  defp write_to_changelog(commits, path) do
    GitOps.Changelog.write(path, commits)
  end
end
