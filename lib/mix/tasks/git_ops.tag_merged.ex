defmodule Mix.Tasks.GitOps.TagMerged do
  use Mix.Task

  @shortdoc "Tags released versions that have no tag yet, and creates their GitHub releases"

  @moduledoc """
  The second phase of the `pull_request` release strategy.

      mix git_ops.tag_merged

  Merging a release pull request updates each package's version file; this
  task reconciles tags to match. For every package whose version file holds a
  version with no corresponding tag, it tags the commit that set that
  version, pushes the tag, and creates a GitHub release with the package's
  changelog entry (when a `GITHUB_TOKEN` is available).

  It is idempotent and safe to run on every push to the release branch.

  ## Switches:

  * `--dry-run` - Print what would be tagged without tagging.
  """

  alias GitOps.Config
  alias GitOps.Git

  @version_file_search_depth 500

  @doc false
  def run(args) do
    {opts, _} = OptionParser.parse!(args, strict: [dry_run: :boolean], aliases: [d: :dry_run])

    repo = Git.init!(Config.repository_path())
    remote_tags = Git.remote_tags(repo)

    tagged =
      Config.packages()
      |> Enum.filter(& &1.version_file)
      |> Enum.flat_map(&tag_package(repo, &1, remote_tags, opts))

    if Enum.empty?(tagged) do
      Mix.shell().info("No untagged releases.")
    end
  end

  defp tag_package(repo, package, remote_tags, opts) do
    with {:ok, version} <- version_at(repo, package, "HEAD"),
         tag = package.prefix <> version,
         false <- MapSet.member?(remote_tags, tag) do
      if opts[:dry_run] do
        Mix.shell().info("Dry run: would tag #{tag} and create its GitHub release.")
        [tag]
      else
        create_tag(repo, package, version, tag)
      end
    else
      _ -> []
    end
  end

  defp create_tag(repo, package, version, tag) do
    {path, _} = package.version_file

    sha =
      repo
      |> Git.commits_touching!(path, @version_file_search_depth)
      |> Enum.find(fn sha ->
        version_at(repo, package, sha) == {:ok, version} &&
          version_at(repo, package, sha <> "^") != {:ok, version}
      end)

    if sha do
      notes = changelog_entry(repo, package, version)

      Git.tag!(repo, ["-a", tag, sha, "-m", "release #{tag}\n\n#{notes}"])
      Git.push!(repo, "refs/tags/#{tag}", "refs/tags/#{tag}")
      Mix.shell().info("Tagged #{tag} at #{String.slice(sha, 0, 10)}.")

      case GitOps.GitHub.create_release(tag, tag, notes) do
        {:ok, url} ->
          Mix.shell().info("Release: #{url}")

        {:error, error} ->
          Mix.shell().error("Could not create the GitHub release for #{tag}: #{error}")
      end

      [tag]
    else
      Mix.shell().error(
        "#{package.name}: version #{version} is untagged, but no commit setting it was found " <>
          "in the last #{@version_file_search_depth} commits touching #{path}. Skipping."
      )

      []
    end
  end

  defp version_at(repo, package, ref) do
    {path, pattern} = package.version_file

    with {:ok, contents} <- Git.show(repo, ref, path),
         [_, version | _] <- Regex.run(pattern, contents) do
      {:ok, version}
    else
      _ -> :error
    end
  end

  defp changelog_entry(repo, package, version) do
    with {:ok, contents} <- Git.show(repo, "HEAD", package.changelog_file),
         [{start, length}] <-
           Regex.run(~r/^##+ \[?v?#{Regex.escape(version)}[\]\s(].*$/m, contents, return: :index) do
      rest = binary_part(contents, start + length, byte_size(contents) - start - length)

      entry_body =
        case Regex.run(~r/^## /m, rest, return: :index) do
          [{next, _}] -> binary_part(rest, 0, next)
          nil -> rest
        end

      String.trim(binary_part(contents, start, length) <> entry_body)
    else
      _ -> ""
    end
  end
end
