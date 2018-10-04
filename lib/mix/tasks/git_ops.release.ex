defmodule Mix.Tasks.GitOps.Release do
  use Mix.Task

  @shortdoc "Parses the commit log and writes any updates to the changelog"

  @doc false
  def run(args) do
    changelog_file = GitOps.Config.changelog_file()
    path = Path.expand(changelog_file)
    mix_project_module = GitOps.Config.mix_project()
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

    config_types = GitOps.Config.types()

    commits =
      commit_messages
      |> Enum.flat_map(fn text ->
        case GitOps.Commit.parse(text) do
          {:ok, commit} ->
            if Map.has_key?(config_types, String.downcase(commit.type)) do
              [commit]
            else
              Mix.shell().error("Commit with unknown type: #{text}")
              []
            end

          _ ->
            Mix.shell().error("Unparseable commit: #{text}")
            []
        end
      end)

    new_version = GitOps.Version.determine_new_version(current_version, commits)

    GitOps.Changelog.write(path, commits, current_version, new_version)

    if GitOps.Config.manage_mix_version?() do
      GitOps.VersionReplace.update_mix_project(mix_project_module, current_version, new_version)
    end

    readme = GitOps.Config.manage_readme_version()

    if readme do
      GitOps.VersionReplace.update_readme(readme, current_version, new_version)
    end

    GitOps.Git.tag!(repo, new_version)

    :ok
  end

  def get_opts(args) do
    {opts, _} = OptionParser.parse!(args, strict: [initial: :boolean], aliases: [i: :initial])

    opts
  end
end
