defmodule Mix.Tasks.GitOps.Release do
  use Mix.Task

  @shortdoc "Parses the commit log and writes any updates to the changelog"

  @moduledoc """
  Updates project changelog, and any other configured release capabilities.

      mix git_ops.release


  Logs an error for any commits that were not parseable.

  In the case that the prior version was a pre-release and this one is not,
  the version is only updated via removing the pre-release identifier.

  For more information on semantic versioning, including pre release and build identifiers,
  see the specification here: https://semver.org/

  ## Switches:

      * `--initial` - Creates the first changelog, and sets the version to whatever the
        configured mix project's version is.

      * `--pre-release` - Sets this release to be a pre release, using the configured
        string as the pre release identifier. This is a manual process, and results in
        an otherwise unchanged version. (Does not change the minor version).
        The version number will only change if a *higher* version number bump is required
        than what was originally changed in the creation of the RC. For instance, if patch
        was changed when creating the pre-release, and no fixes or features were added when
        requesting a new pre-release, then the version will not change. However, if the last
        pre-release had only a patch version bump, but a major change has since been added,
        the version will be changed accordingly.

      * `--rc` - Overrides the presence of `--pre-release`, and manages an incrementing
        identifier as the prerelease. This will look like `1.0.0-rc0` `1.0.0-rc1` and so
        forth. See the `--pre-release` flag for information on when the version will change
        for a pre-release. In the case that the version must change, the counter for
        the release candidate counter will be reset as well.

      * `--build` - Sets the release build metadata. Build information has no semantic
        meaning to the version itself, and so is simply attached to the end and is to
        be used to describe the build conditions for that release. You might build the
        same version many times, and this can be used to denote that in whatever way
        you choose.

      * `--force-patch` - In cases where this task is run, but the version should not
        change, this option will force the patch number to be incremented.

      * `--no-major` - Forces major version changes to instead only result in minor version
        changes. This would be a common option for libraries that are still in 0.x.x phases
        where 1.0.0 should only happen at some specified milestones. After that, it is important
        to *not* resist a 2.x.x change just because it doesn't seem like it deserves it.
        Semantic versioning uses this major version change to communicate, and it should not be
        reserved.
  """

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

    tags = GitOps.Git.tags(repo)

    commit_messages =
      if opts[:initial] do
        GitOps.Git.get_initial_commits!(repo)
      else
        tag = GitOps.Version.last_valid_non_rc_version(tags)

        GitOps.Git.commit_messages_since_tag(repo, tag)
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

    new_version =
      if opts[:initial] do

        mix_project_module.project()[:version]
      else
GitOps.Version.determine_new_version(tags, commits, opts)
      end

    GitOps.Changelog.write(path, commits, current_version, new_version)

    if GitOps.Config.manage_mix_version?() do
      GitOps.VersionReplace.update_mix_project(mix_project_module, current_version, new_version)
    end

    readme = GitOps.Config.manage_readme_version()

    if readme do
      GitOps.VersionReplace.update_readme(readme, current_version, new_version)
    end

    GitOps.Git.tag!(repo, new_version)

    IO.puts("All thats left is to commit and push (don't forget to push the tag as well!)")

    :ok
  end

  def get_opts(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          build: :string,
          force_patch: :boolean,
          initial: :boolean,
          no_major: :boolean,
          pre_release: :string,
          rc: :boolean
        ],
        aliases: [i: :initial, p: :pre_release, b: :build, f: :force_patch, n: :no_major]
      )

    opts
  end
end
