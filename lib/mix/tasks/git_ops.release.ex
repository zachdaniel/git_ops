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

  * `--dry-run` - Allow users to run release process and view changes without committing and tagging

  * `--yes` - Don't prompt for confirmation, just perform release.  Useful for your CI run.
  """

  alias GitOps.Changelog
  alias GitOps.Commit
  alias GitOps.Config
  alias GitOps.Git
  alias GitOps.VersionReplace

  @doc false
  def run(args) do
    opts = get_opts(args)

    Config.mix_project_check(opts)

    mix_project_module = Config.mix_project()
    mix_project = mix_project_module.project()

    changelog_file = Config.changelog_file()
    changelog_path = Path.expand(changelog_file)

    current_version = String.trim(mix_project[:version])

    repo = Git.init!()

    if opts[:initial] do
      Changelog.initialize(changelog_path, opts)
    end

    tags = Git.tags(repo)

    prefix = Config.prefix()

    config_types = Config.types()

    {commit_messages_for_version, commit_messages_for_changelog} =
      get_commit_messages(repo, prefix, tags, opts)

    log_for_version? = !opts[:initial]

    commits_for_version =
      parse_commits(commit_messages_for_version, config_types, log_for_version?)

    commits_for_changelog = parse_commits(commit_messages_for_changelog, config_types, false)

    prefixed_new_version =
      if opts[:initial] do
        prefix <> mix_project[:version]
      else
        GitOps.Version.determine_new_version(
          current_version,
          prefix,
          commits_for_version,
          opts
        )
      end

    new_version =
      if prefix != "" do
        String.trim_leading(prefixed_new_version, prefix)
      else
        prefixed_new_version
      end

    changelog_changes =
      Changelog.write(
        changelog_path,
        commits_for_changelog,
        current_version,
        prefixed_new_version,
        opts
      )

    create_and_display_changes(current_version, new_version, changelog_changes, opts)

    cond do
      opts[:dry_run] ->
        :ok

      opts[:yes] ->
        tag(repo, changelog_file, prefixed_new_version, changelog_changes)
        :ok

      true ->
        confirm_and_tag(repo, changelog_file, prefixed_new_version, changelog_changes)
        :ok
    end
  end

  defp get_commit_messages(repo, prefix, tags, opts) do
    if opts[:initial] do
      commits = Git.get_initial_commits!(repo)
      {commits, commits}
    else
      tag =
        if opts[:rc] do
          GitOps.Version.last_valid_version(tags, prefix)
        else
          GitOps.Version.last_valid_non_rc_version(tags, prefix)
        end

      commits_for_version = Git.commit_messages_since_tag(repo, tag)

      last_version_after = GitOps.Version.last_version_greater_than(tags, tag, prefix)

      if last_version_after do
        commit_messages_for_changelog = Git.commit_messages_since_tag(repo, last_version_after)

        {commits_for_version, commit_messages_for_changelog}
      else
        {commits_for_version, commits_for_version}
      end
    end
  end

  defp create_and_display_changes(current_version, new_version, changelog_changes, opts) do
    changelog_file = Config.changelog_file()
    mix_project_module = Config.mix_project()
    readme = Config.manage_readme_version()

    Mix.shell().info("Your new version is: #{new_version}\n")

    mix_project_changes =
      if Config.manage_mix_version?() do
        VersionReplace.update_mix_project(
          mix_project_module,
          current_version,
          new_version,
          opts
        )
      end

    readme_changes =
      readme
      |> List.wrap()
      |> Enum.map(fn readme ->
        {readme, VersionReplace.update_readme(readme, current_version, new_version, opts)}
      end)

    if opts[:dry_run] do
      "Below are the contents of files that will change.\n"
      |> append_changes_to_message(changelog_file, changelog_changes)
      |> add_readme_changes(readme_changes)
      |> append_changes_to_message(mix_project_module, mix_project_changes)
      |> Mix.shell().info()
    end
  end

  defp add_readme_changes(message, readme_changes) do
    Enum.reduce(readme_changes, message, fn {file, changes}, message ->
      append_changes_to_message(message, file, changes)
    end)
  end

  defp tag(repo, changelog_file, new_version, new_message) do
    Git.add!(repo, "#{changelog_file}")
    Git.commit!(repo, ["-am", "chore: release version #{new_version}"])

    new_message =
      new_message
      |> String.replace(~r/^#+/m, "")
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n")

    Git.tag!(repo, ["-a", new_version, "-m", "release #{new_version}\n\n" <> new_message])

    Mix.shell().info("Don't forget to push with tags:\n\n    git push --follow-tags")
  end

  defp confirm_and_tag(repo, changelog_file, new_version, new_message) do
    message = """
    Shall we commit and tag?

    Instructions will be printed for committing and tagging if you choose no.
    """

    if Mix.shell().yes?(message) do
      tag(repo, changelog_file, new_version, new_message)
    else
      Mix.shell().info("""
      If you want to do it on your own, make sure you tag the release with:

      If you want to include your release notes in the tag message, use

          git commit -am "chore: release version #{new_version}"
          git tag -a #{new_version}

      And replace the contents with your release notes (make sure to escape any # with \#)

      Otherwise, use:

          git commit -am "chore: release version #{new_version}"
          git tag -a #{new_version} -m "release #{new_version}"
          git push --follow-tags
      """)
    end
  end

  defp parse_commits(messages, config_types, log?) do
    Enum.flat_map(messages, &parse_commit(&1, config_types, log?))
  end

  defp parse_commit(text, config_types, log?) do
    case Commit.parse(text) do
      {:ok, commits} ->
        commits_with_type(config_types, commits, text, log?)

      _ ->
        error_if_log("Unparseable commit: #{text}", log?)

        []
    end
  end

  defp commits_with_type(config_types, commits, text, log?) do
    Enum.flat_map(commits, fn commit ->
      if Map.has_key?(config_types, String.downcase(commit.type)) do
        [commit]
      else
        error_if_log("Commit with unknown type in: #{text}", log?)

        []
      end
    end)
  end

  defp append_changes_to_message(message, _, {:error, :bad_replace}), do: message

  defp append_changes_to_message(message, file, changes) do
    message <> "----- BEGIN #{file} -----\n\n#{changes}\n----- END #{file} -----\n\n"
  end

  defp error_if_log(error, _log? = true), do: Mix.shell().error(error)
  defp error_if_log(_, _), do: :ok

  defp get_opts(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          build: :string,
          force_patch: :boolean,
          initial: :boolean,
          no_major: :boolean,
          pre_release: :string,
          rc: :boolean,
          dry_run: :boolean,
          yes: :boolean
        ],
        aliases: [
          i: :initial,
          p: :pre_release,
          b: :build,
          f: :force_patch,
          n: :no_major,
          d: :dry_run,
          y: :yes
        ]
      )

    opts
  end
end
