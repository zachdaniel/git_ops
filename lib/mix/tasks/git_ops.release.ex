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
    configured `version_source` currently reports (the mix project's version by default).

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

  * `--output` - A directory to write proposed release contents into (pull request bodies and
    updated files). Useful with `--dry-run` to inspect what a release would do.

  * `--yes` - Don't prompt for confirmation, just perform release.  Useful for your CI run.

  * `--override` - Provide an explicit version override
  """

  alias GitOps.Changelog
  alias GitOps.Commit
  alias GitOps.Config
  alias GitOps.Git
  alias GitOps.Package
  alias GitOps.VersionReplace

  @doc false
  def run(args) do
    opts = get_opts(args)

    Config.mix_project_check(opts)

    case {Config.release_strategy(), Config.packages()} do
      {:pull_request, packages} -> run_pull_request(packages, opts)
      {:commit, [%Package{root?: true} = package]} -> run_single(package, opts)
      {:commit, packages} -> run_packages(packages, opts)
    end
  end

  defp run_pull_request(packages, opts) do
    reject_unsupported_switches(packages, opts)

    repo = Git.init!(Config.repository_path())

    plans =
      packages
      |> Enum.map(&plan_package(repo, &1, packages, opts))
      |> Enum.reject(&is_nil/1)
      |> apply_linked_packages(repo, packages, opts)

    if Enum.empty?(plans) do
      Mix.shell().info("No packages have releasable changes.")
    else
      base_branch = Git.current_branch!(repo)

      plans
      |> Enum.group_by(fn plan -> plan.package.pr_group || plan.package.name || "release" end)
      |> Enum.sort_by(fn {name, _} -> name end)
      |> Enum.each(fn {name, unit_plans} ->
        propose_unit(repo, name, unit_plans, base_branch, opts)
      end)
    end
  end

  defp propose_unit(repo, name, plans, base_branch, opts) do
    branch = "git-ops/release/#{name}"
    {plans, files} = render_unit(repo, plans, opts)

    title =
      case plans do
        [plan] -> "chore: release #{plan.package.name || name} #{plan.new_version}"
        _ -> "chore: release #{name}"
      end

    body =
      "Merging this pull request releases:\n\n" <>
        Enum.map_join(plans, "\n\n", fn plan ->
          "**#{plan.package.name || name}**\n\n#{plan.entry}"
        end)

    Enum.each(plans, fn plan ->
      Mix.shell().info("#{plan.package.name || name}: #{plan.current} -> #{plan.new_version}")
    end)

    if output = opts[:output] do
      dir = Path.join(output, name)
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "PR_BODY.md"), body)

      Enum.each(files, fn {path, contents} ->
        File.write!(Path.join(dir, String.replace(path, "/", "__")), contents)
      end)
    end

    if opts[:dry_run] do
      Mix.shell().info("Dry run: would push #{branch} and open a pull request.\n")
    else
      sha = Git.commit_tree!(repo, "HEAD", files, title)
      Git.push!(repo, sha, "refs/heads/#{branch}")

      case GitOps.GitHub.upsert_pull_request(branch, base_branch, title, body, Config.pr_labels()) do
        {:ok, url} -> Mix.shell().info("Pull request: #{url}\n")
        {:error, error} -> Mix.raise("Could not open pull request for #{branch}: #{error}")
      end
    end
  end

  defp render_unit(repo, plans, opts) do
    Enum.map_reduce(plans, %{}, fn plan, files ->
      package = plan.package

      existing_changelog =
        case Git.show(repo, "HEAD", package.changelog_file) do
          {:ok, contents} -> contents
          :error -> Changelog.initial_contents()
        end

      {changelog_contents, entry} =
        Changelog.render(
          existing_changelog,
          plan.commits,
          plan.current,
          plan.new_version,
          Keyword.put(opts, :prefix, package.prefix)
        )

      files = Map.put(files, package.changelog_file, changelog_contents)

      files =
        Enum.reduce(package.managed_files, files, fn {path, _, _} = managed_file, files ->
          with {:ok, contents} <- Git.show(repo, "HEAD", path),
               {:ok, new_contents} <-
                 VersionReplace.render(managed_file, contents, plan.current, plan.new_version) do
            Map.put(files, path, new_contents)
          else
            _ ->
              Mix.shell().error(
                "#{package.name}: could not update version #{plan.current} in #{path}, skipping"
              )

              files
          end
        end)

      {%{plan | entry: entry}, files}
    end)
  end

  defp reject_unsupported_switches(packages, opts) do
    unsupported =
      if Config.release_strategy() == :pull_request || length(packages) > 1 do
        [:rc, :pre_release, :build, :override, :initial]
      else
        []
      end

    Enum.each(unsupported, fn switch ->
      if opts[switch] do
        Mix.raise(
          "--#{switch} is not supported with multiple packages or the pull_request strategy"
        )
      end
    end)
  end

  defp run_single(package, opts) do
    changelog_file = Config.changelog_file()
    changelog_path = Path.expand(changelog_file)

    repo_path = Config.repository_path()
    repo = Git.init!(repo_path)

    if opts[:initial] do
      Changelog.initialize(changelog_path, opts)
    end

    tags = Git.tags(repo)

    prefix = Config.prefix()

    current_version = current_version(tags, prefix, opts)

    config_types = Config.types()
    allowed_tags = Config.allowed_tags()
    allow_untagged? = Config.allow_untagged?()
    from_rc? = Version.parse!(current_version).pre != []

    log_opts = [
      paths: Enum.map(package.exclude_paths, &":^#{&1}"),
      first_parent: Config.first_parent?()
    ]

    {commit_messages_for_version, commit_messages_for_changelog, commit_authors, hashes} =
      get_commit_messages(repo, prefix, tags, from_rc?, opts, log_opts)

    github_info =
      if Config.github_handle_lookup?() do
        fetch_github_information(commit_authors, hashes)
      else
        nil
      end

    log_for_version? = !opts[:initial]

    commits_for_version =
      parse_commits(
        commit_messages_for_version,
        commit_authors,
        hashes,
        config_types,
        allowed_tags,
        allow_untagged?,
        log_for_version?
      )

    commits_for_changelog =
      commit_messages_for_changelog
      |> parse_commits(
        commit_authors,
        hashes,
        config_types,
        allowed_tags,
        allow_untagged?,
        false
      )
      |> enrich_commits_with_github_information(github_info)

    prefixed_new_version =
      if opts[:initial] do
        prefix <> current_version
      else
        GitOps.Version.determine_new_version(
          current_version,
          prefix,
          commits_for_version,
          GitOps.Version.last_valid_non_rc_version(tags, prefix),
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

    new_parsed = Version.parse!(new_version)
    upgrading_from_rc? = from_rc? && new_parsed.pre == []

    cond do
      opts[:dry_run] ->
        :ok

      upgrading_from_rc? ->
        confirm_rc_upgrade(repo, changelog_path, prefixed_new_version, changelog_changes)
        :ok

      opts[:yes] ->
        tag(repo, changelog_path, prefixed_new_version, changelog_changes)
        :ok

      true ->
        confirm_and_tag(repo, changelog_path, prefixed_new_version, changelog_changes)
        :ok
    end
  end

  defp run_packages(packages, opts) do
    reject_unsupported_switches(packages, opts)

    repo = Git.init!(Config.repository_path())

    plans =
      packages
      |> Enum.map(&plan_package(repo, &1, packages, opts))
      |> Enum.reject(&is_nil/1)
      |> apply_linked_packages(repo, packages, opts)

    if Enum.empty?(plans) do
      Mix.shell().info("No packages have releasable changes.")
    else
      {plans, changed_files} =
        Enum.map_reduce(plans, [], fn plan, files ->
          {plan, plan_files} = write_plan(plan, opts)
          {plan, files ++ plan_files}
        end)

      Enum.each(plans, fn plan ->
        Mix.shell().info("#{plan.package.name}: #{plan.current} -> #{plan.new_version}")
      end)

      cond do
        opts[:dry_run] ->
          :ok

        opts[:yes] || Mix.shell().yes?("\nShall we commit and tag?") ->
          commit_and_tag(repo, plans, changed_files)

        true ->
          Mix.shell().info("Aborted. Files were updated but not committed.")
      end
    end
  end

  defp plan_package(repo, package, packages, opts) do
    tags = Git.tags(repo, package.prefix)
    last_tag = GitOps.Version.last_valid_non_rc_version(tags, package.prefix)
    current = package_current_version(package, tags)

    if current == nil do
      Mix.shell().error(
        "#{package.name}: no current version found. Tag an initial version, e.g. " <>
          "`git tag #{package.prefix}0.1.0`, or configure a version_source. Skipping."
      )

      nil
    else
      commits = package_commits(repo, package, packages, last_tag, opts)

      bump? =
        Enum.any?(commits, &(Commit.breaking?(&1) || Commit.feature?(&1) || Commit.fix?(&1)))

      releasable? = commits != [] && (bump? || package.patch_on_any_change? || opts[:force_patch])

      if releasable? do
        effective_opts = if bump?, do: opts, else: Keyword.put(opts, :force_patch, true)

        prefixed_new_version =
          GitOps.Version.determine_new_version(
            current,
            package.prefix,
            commits,
            last_tag,
            effective_opts
          )

        %{
          package: package,
          current: current,
          new_version: String.trim_leading(prefixed_new_version, package.prefix),
          prefixed_new_version: prefixed_new_version,
          commits: commits,
          entry: nil
        }
      end
    end
  end

  defp package_current_version(package, tags) do
    case package.version_source do
      :mix ->
        String.trim(Config.mix_project().project()[:version])

      :tags ->
        case GitOps.Version.last_valid_version(tags, package.prefix) do
          nil -> nil
          tag -> String.trim_leading(tag, package.prefix)
        end

      {:file, path, pattern} ->
        case Regex.run(pattern, File.read!(path)) do
          [_, version | _] ->
            version

          _ ->
            Mix.raise("version_source file #{path} did not match the configured version pattern")
        end
    end
  end

  defp package_commits(repo, package, packages, last_tag, _opts) do
    commit_info =
      Git.get_commit_info(repo, last_tag || :all,
        paths: package_paths(package, packages),
        first_parent: Config.first_parent?()
      )

    messages = Enum.map(commit_info, & &1.message)
    authors = Enum.map(commit_info, &{&1.author_name, &1.author_email})
    hashes = Enum.map(commit_info, & &1.hash)

    parse_commits(
      messages,
      authors,
      hashes,
      Config.types(),
      Config.allowed_tags(),
      Config.allow_untagged?(),
      false
    )
  end

  # A commit belongs to the deepest package containing it, so a package's
  # pathspec excludes every package nested inside it.
  defp package_paths(package, packages) do
    nested =
      for other <- packages,
          other.path != package.path,
          package.path == "." || String.starts_with?(other.path, package.path <> "/"),
          do: other.path

    excludes = package.exclude_paths ++ nested

    [package.path | Enum.map(excludes, &":^#{&1}")]
  end

  defp apply_linked_packages(plans, repo, packages, opts) do
    Enum.reduce(Config.linked_packages(), plans, fn group, plans ->
      group_plans = Enum.filter(plans, &(&1.package.path in group))

      if Enum.empty?(group_plans) do
        plans
      else
        target =
          group_plans
          |> Enum.map(& &1.new_version)
          |> Enum.max_by(&Version.parse!/1, Version)

        planned_paths = Enum.map(group_plans, & &1.package.path)

        synced =
          for package <- packages,
              package.path in group,
              package.path not in planned_paths,
              current = package_current_version(package, Git.tags(repo, package.prefix)),
              current != nil,
              current != target,
              do: sync_plan(package, current, target, opts)

        Enum.map(plans, fn plan ->
          if plan.package.path in group do
            %{
              plan
              | new_version: target,
                prefixed_new_version: plan.package.prefix <> target
            }
          else
            plan
          end
        end) ++ synced
      end
    end)
  end

  defp sync_plan(package, current, target, _opts) do
    commit = %Commit{
      type: "chore",
      message: "synchronize linked package versions",
      breaking?: false
    }

    %{
      package: package,
      current: current,
      new_version: target,
      prefixed_new_version: package.prefix <> target,
      commits: [commit],
      entry: nil
    }
  end

  defp write_plan(plan, opts) do
    package = plan.package
    changelog = package.changelog_file

    if !File.exists?(changelog) && !opts[:dry_run] do
      Changelog.initialize(changelog, opts)
    end

    entry =
      if File.exists?(changelog) do
        Changelog.write(
          changelog,
          plan.commits,
          plan.current,
          plan.new_version,
          Keyword.put(opts, :prefix, package.prefix)
        )
      else
        ""
      end

    managed =
      Enum.flat_map(package.managed_files, fn {path, _, _} = managed_file ->
        case VersionReplace.update_managed_file(
               managed_file,
               plan.current,
               plan.new_version,
               opts
             ) do
          {:error, :bad_replace} ->
            Mix.shell().error(
              "#{package.name}: could not find version #{plan.current} in #{path}, skipping"
            )

            []

          _ ->
            [path]
        end
      end)

    {%{plan | entry: entry}, [changelog | managed]}
  end

  defp commit_and_tag(repo, plans, changed_files) do
    Git.add!(repo, changed_files)
    Git.commit!(repo, ["-m", packages_commit_message(plans)])

    Enum.each(plans, fn plan ->
      Git.tag!(repo, [
        "-a",
        plan.prefixed_new_version,
        "-m",
        "release #{plan.prefixed_new_version}\n\n" <> release_notes(plan.entry)
      ])
    end)

    Mix.shell().info("Don't forget to push with tags:\n\n    git push --follow-tags")
  end

  defp packages_commit_message([plan]) do
    "chore: release version #{plan.prefixed_new_version}"
  end

  defp packages_commit_message(plans) do
    "chore: release " <> Enum.map_join(plans, ", ", &"#{&1.package.name} #{&1.new_version}")
  end

  defp current_version(tags, prefix, opts) do
    case Config.version_source() do
      :mix ->
        String.trim(Config.mix_project().project()[:version])

      :tags ->
        case GitOps.Version.last_valid_version(tags, prefix) do
          nil ->
            opts[:override] ||
              Mix.raise("""
              version_source is :tags, but no valid version tag was found#{prefix_note(prefix)}.

              Use `--override` to set the version explicitly.
              """)

          tag ->
            String.trim_leading(tag, prefix)
        end

      {:file, path, %Regex{} = pattern} ->
        case Regex.run(pattern, File.read!(path)) do
          [_, version | _] ->
            version

          _ ->
            Mix.raise("version_source file #{path} did not match the configured version pattern")
        end
    end
  end

  defp prefix_note(""), do: ""
  defp prefix_note(prefix), do: " (with prefix #{inspect(prefix)})"

  defp get_commit_messages(repo, prefix, tags, _from_rc?, opts, log_opts) do
    if opts[:initial] do
      commit_info = Git.get_commit_info(repo, :all, log_opts)

      commits = [
        Git.initial_commit_message() | Enum.map(commit_info, & &1.message)
      ]

      authors = Enum.map(commit_info, &{&1.author_name, &1.author_email})
      hashes = Enum.map(commit_info, & &1.hash)
      {commits, commits, authors, hashes}
    else
      tag =
        if opts[:rc] do
          GitOps.Version.last_valid_version(tags, prefix)
        else
          GitOps.Version.last_valid_non_rc_version(tags, prefix)
        end

      unless Git.tag_exists?(repo, tag) do
        Mix.raise("""
        The tag #{tag} was found in the tag list but does not exist locally.
        This can happen when tags have not been fetched from the remote.

        Run `git fetch --tags` and try again.
        """)
      end

      commit_info = Git.get_commit_info(repo, tag, log_opts)
      commits_for_version = Enum.map(commit_info, & &1.message)
      authors = Enum.map(commit_info, &{&1.author_name, &1.author_email})
      hashes = Enum.map(commit_info, & &1.hash)

      last_version_after = GitOps.Version.last_version_greater_than(tags, tag, prefix)

      if last_version_after && !opts[:rc] do
        changelog_commit_info = Git.get_commit_info(repo, last_version_after, log_opts)
        commit_messages_for_changelog = Enum.map(changelog_commit_info, & &1.message)
        changelog_authors = Enum.map(changelog_commit_info, &{&1.author_name, &1.author_email})
        hashes = Enum.map(changelog_commit_info, & &1.hash)

        {commits_for_version, commit_messages_for_changelog, changelog_authors, hashes}
      else
        {commits_for_version, commits_for_version, authors, hashes}
      end
    end
  end

  defp create_and_display_changes(current_version, new_version, changelog_changes, opts) do
    changelog_file = Config.changelog_file()

    Mix.shell().info("Your new version is: #{new_version}\n")

    managed_file_changes =
      Config.managed_files()
      |> Enum.map(fn {path, _replace, _pattern} = managed_file ->
        {path,
         VersionReplace.update_managed_file(managed_file, current_version, new_version, opts)}
      end)

    if opts[:dry_run] do
      "Below are the contents of files that will change.\n"
      |> append_changes_to_message(changelog_file, changelog_changes)
      |> add_managed_file_changes(managed_file_changes)
      |> Mix.shell().info()
    end
  end

  defp add_managed_file_changes(message, managed_file_changes) do
    Enum.reduce(managed_file_changes, message, fn {file, changes}, message ->
      append_changes_to_message(message, file, changes)
    end)
  end

  defp tag(repo, changelog_path, new_version, new_message) do
    Git.add!(repo, [changelog_path])
    Git.commit!(repo, ["-am", "chore: release version #{new_version}"])

    Git.tag!(repo, [
      "-a",
      new_version,
      "-m",
      "release #{new_version}\n\n" <> release_notes(new_message)
    ])

    Mix.shell().info("Don't forget to push with tags:\n\n    git push --follow-tags")
  end

  defp release_notes(changelog_entry) do
    changelog_entry
    |> String.replace(~r/^#+/m, "")
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  defp confirm_rc_upgrade(repo, changelog_path, new_version, new_message) do
    confirm_tag(repo, changelog_path, new_version, new_message, """
    You are releasing #{new_version}, which is a stable release from a release candidate.

    Are you sure you want to proceed?

    Instructions will be printed for committing and tagging if you choose no.
    """)
  end

  defp confirm_and_tag(repo, changelog_path, new_version, new_message) do
    confirm_tag(repo, changelog_path, new_version, new_message, """
    Shall we commit and tag?

    Instructions will be printed for committing and tagging if you choose no.
    """)
  end

  defp confirm_tag(repo, changelog_path, new_version, new_message, prompt) do
    if Mix.shell().yes?(prompt) do
      tag(repo, changelog_path, new_version, new_message)
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

  defp parse_commits(messages, authors, hashes, config_types, allowed_tags, allow_untagged?, log?) do
    [messages, authors, hashes]
    |> Enum.zip()
    |> Enum.flat_map(fn {message, author, hash} ->
      parse_commit(message, author, hash, config_types, allowed_tags, allow_untagged?, log?)
    end)
  end

  defp parse_commit(text, author, hash, config_types, allowed_tags, allow_untagged?, log?) do
    case Commit.parse(%{text: text, author_info: author, hash: hash}) do
      {:ok, commits} ->
        commits
        |> commits_with_allowed_tags(allowed_tags, allow_untagged?)
        |> commits_with_type(config_types, text, log?)

      _ ->
        error_if_log("Unparseable commit: #{text}", log?)

        []
    end
  end

  @spec fetch_github_information(list(), list()) :: {authors :: map(), prs :: map()} | nil
  defp fetch_github_information(commit_authors, commit_hashes) do
    github_lookup_map = fetch_github_emails(commit_authors)
    pr_lookup_map = GitOps.GitHub.batch_pull_requests_from_commits(commit_hashes)
    {github_lookup_map, pr_lookup_map}
  end

  defp fetch_github_emails(commit_authors) do
    commit_authors
    |> Enum.map(fn {_name, email} -> email end)
    |> Enum.reject(&is_nil/1)
    |> GitOps.GitHub.batch_find_users_by_emails()
  end

  defp enrich_commits_with_github_information(commits, nil), do: commits

  defp enrich_commits_with_github_information(commits, {author_lookup, pr_lookup}) do
    Enum.map(commits, fn commit ->
      github_user_data =
        case Map.get(author_lookup, commit.author_email) do
          {:ok, user_data} -> user_data
          _ -> nil
        end

      pr_info =
        case Map.get(pr_lookup, commit.hash) do
          {:ok, pr_info} -> pr_info
          _ -> nil
        end

      commit
      |> Map.put(:github_user_data, github_user_data)
      |> Map.put(:pr_info, pr_info)
    end)
  end

  defp commits_with_allowed_tags(commits, :any, _), do: commits

  defp commits_with_allowed_tags(commits, allowed_tags, allow_untagged?) do
    case Enum.find(commits, fn %{type: type} -> type == "TAGS" end) do
      nil ->
        if allow_untagged?, do: commits, else: []

      commit ->
        tags = commit.message |> String.split(",", trim: true) |> Enum.map(&String.trim/1)

        if Enum.any?(tags, fn tag -> tag in allowed_tags end) do
          commits
        else
          []
        end
    end
  end

  defp commits_with_type(commits, config_types, text, log?) do
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
          yes: :boolean,
          override: :string,
          output: :string
        ],
        aliases: [
          i: :initial,
          p: :pre_release,
          b: :build,
          f: :force_patch,
          n: :no_major,
          d: :dry_run,
          y: :yes,
          o: :override
        ]
      )

    opts
  end
end
