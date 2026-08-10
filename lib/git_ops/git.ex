defmodule GitOps.Git do
  @moduledoc """
  Helper functions for working with `Git` and fetching the tags/commits we care about.
  """

  @default_githooks_path ".git/hooks"

  @type commit_info :: %{
          hash: String.t(),
          message: String.t(),
          author_name: String.t(),
          author_email: String.t()
        }

  @spec init!(String.t()) :: Git.Repository.t()
  def init!(repo_path) do
    Git.init!(repo_path)
  end

  @spec add!(Git.Repository.t(), [String.t()]) :: String.t()
  def add!(repo, args) do
    Git.add!(repo, args)
  end

  @spec commit!(Git.Repository.t(), [String.t()]) :: String.t()
  def commit!(repo, args) do
    Git.commit!(repo, args)
  end

  @spec tag!(Git.Repository.t(), String.t() | [String.t()]) :: String.t()
  def tag!(repo, current_version) do
    Git.tag!(repo, current_version)
  end

  def initial_commit_message, do: "chore(GitOps): Add changelog using git_ops."

  @spec tags(Git.Repository.t()) :: [String.t()]
  def tags(repo) do
    tags =
      repo
      |> Git.rev_list!(["--tags"])
      |> String.split("\n", trim: true)

    semver_tags =
      repo
      |> Git.describe!(["--always", "--abbrev=0", "--tags"] ++ tags)
      |> String.split("\n", trim: true)

    if Enum.empty?(semver_tags) do
      raise """
      Could not find an appropriate semver tag in git history. Ensure that you have initialized the project and commited the result.
      """
    else
      semver_tags
    end
  end

  @doc """
  All tags starting with `prefix`, newest version first.

  Unlike `tags/1`, returns an empty list when nothing matches, so callers can
  treat "never released" as a normal state.
  """
  @spec tags(Git.Repository.t(), String.t()) :: [String.t()]
  def tags(repo, prefix) do
    repo
    |> Git.tag!(["--list", "#{prefix}*", "--sort=-v:refname"])
    |> String.split("\n", trim: true)
  end

  @spec tag_exists?(Git.Repository.t(), String.t()) :: boolean()
  def tag_exists?(repo, tag) do
    case Git.rev_parse(repo, ["--verify", "refs/tags/#{tag}"]) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Commit info since a tag (or all commits), newest first.

  Options:

  * `:paths` - pathspecs restricting which commits count (git pathspec
    syntax, so `:^dir` entries exclude).
  * `:first_parent` - follow only the first parent of merge commits.
  """
  @spec get_commit_info(Git.Repository.t(), String.t() | :all, Keyword.t()) :: [commit_info()]
  def get_commit_info(repo, since_tag \\ :all, opts \\ []) do
    format = "--format=%H--hash--%B--message--%an--author--%ae--gitops--"

    log_args =
      case since_tag do
        :all -> [format]
        tag -> ["#{tag}..HEAD", format]
      end

    log_args = if opts[:first_parent], do: ["--first-parent" | log_args], else: log_args

    log_args =
      case opts[:paths] do
        paths when is_list(paths) and paths != [] -> log_args ++ ["--" | paths]
        _ -> log_args
      end

    repo
    |> Git.log!(log_args)
    |> parse_git_log()
  end

  @spec parse_git_log(String.t()) :: [commit_info()]
  def parse_git_log(git_log_output) do
    git_log_output
    |> String.split("--gitops--")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&Kernel.==(&1, ""))
    |> Enum.map(&parse_commit_entry/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_commit_entry(commit_string) do
    with [hash, rest] <- String.split(commit_string, "--hash--", parts: 2),
         [message, author_part] <- String.split(rest, "--message--", parts: 2),
         [name, email] <- String.split(author_part, "--author--") do
      %{
        hash: String.trim(hash),
        message: String.trim(message),
        author_name: String.trim(name),
        author_email: String.trim(email)
      }
    else
      _ -> nil
    end
  end

  @doc """
  The contents of `path` at `ref`, or `:error` if it does not exist there.
  """
  @spec show(Git.Repository.t(), String.t(), String.t()) :: {:ok, String.t()} | :error
  def show(repo, ref, path) do
    case cmd(repo, ["show", "#{ref}:#{path}"]) do
      {:ok, contents} -> {:ok, contents}
      _ -> :error
    end
  end

  @doc """
  Commits `files` (a map of repo-relative path to contents) on top of
  `base_ref` using a temporary index, leaving the working tree untouched.
  Returns the new commit's SHA.
  """
  @spec commit_tree!(Git.Repository.t(), String.t(), %{String.t() => String.t()}, String.t()) ::
          String.t()
  def commit_tree!(repo, base_ref, files, message) do
    base = String.trim(cmd!(repo, ["rev-parse", base_ref]))
    tmp = Path.join(System.tmp_dir!(), "git_ops_index_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    env = [{"GIT_INDEX_FILE", Path.join(tmp, "index")}]

    try do
      cmd!(repo, ["read-tree", base], env)

      Enum.each(files, fn {path, contents} ->
        blob_path = Path.join(tmp, "blob")
        File.write!(blob_path, contents)
        blob = String.trim(cmd!(repo, ["hash-object", "-w", blob_path], env))
        cmd!(repo, ["update-index", "--add", "--cacheinfo", "100644,#{blob},#{path}"], env)
      end)

      tree = String.trim(cmd!(repo, ["write-tree"], env))
      String.trim(cmd!(repo, ["commit-tree", tree, "-p", base, "-m", message], env))
    after
      File.rm_rf!(tmp)
    end
  end

  @doc """
  Force-pushes a commit or tag ref to `origin`.
  """
  @spec push!(Git.Repository.t(), String.t(), String.t()) :: :ok
  def push!(repo, source, target) do
    cmd!(repo, ["push", "--force", "origin", "#{source}:#{target}"])
    :ok
  end

  @doc """
  The tag names present on the `origin` remote, or the local tags when there
  is no reachable remote.
  """
  @spec remote_tags(Git.Repository.t()) :: MapSet.t(String.t())
  def remote_tags(repo) do
    case cmd(repo, ["ls-remote", "--tags", "origin"]) do
      {:ok, output} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.flat_map(fn line ->
          case String.split(line, "refs/tags/") do
            [_, tag] -> [String.trim_trailing(tag, "^{}")]
            _ -> []
          end
        end)
        |> MapSet.new()

      _ ->
        repo |> tags("") |> MapSet.new()
    end
  end

  @doc """
  The name of the currently checked out branch.
  """
  @spec current_branch!(Git.Repository.t()) :: String.t()
  def current_branch!(repo) do
    String.trim(cmd!(repo, ["rev-parse", "--abbrev-ref", "HEAD"]))
  end

  @doc """
  The tree hash of the `origin` remote's `branch`, or `nil` when the branch
  does not exist there.
  """
  @spec remote_branch_tree(Git.Repository.t(), String.t()) :: String.t() | nil
  def remote_branch_tree(repo, branch) do
    resolve = fn -> cmd(repo, ["rev-parse", "refs/remotes/origin/#{branch}^{tree}"]) end

    with {:error, _} <- resolve.(),
         {:ok, _} <-
           cmd(repo, ["fetch", "origin", "+refs/heads/#{branch}:refs/remotes/origin/#{branch}"]),
         {:error, _} <- resolve.() do
      nil
    else
      {:ok, tree} -> String.trim(tree)
      _ -> nil
    end
  end

  @doc """
  The tree hash of a commit.
  """
  @spec tree_of!(Git.Repository.t(), String.t()) :: String.t()
  def tree_of!(repo, sha) do
    String.trim(cmd!(repo, ["rev-parse", "#{sha}^{tree}"]))
  end

  @doc """
  The subject line of a commit.
  """
  @spec commit_subject!(Git.Repository.t(), String.t()) :: String.t()
  def commit_subject!(repo, sha) do
    String.trim(cmd!(repo, ["log", "-1", "--format=%s", sha]))
  end

  @doc """
  First-parent commit SHAs of HEAD that touch `path`, newest first.
  """
  @spec commits_touching!(Git.Repository.t(), String.t(), pos_integer()) :: [String.t()]
  def commits_touching!(repo, path, limit) do
    repo
    |> cmd!(["log", "--first-parent", "--format=%H", "-n", to_string(limit), "HEAD", "--", path])
    |> String.split("\n", trim: true)
  end

  defp cmd(repo, args, env \\ []) do
    case System.cmd("git", args, cd: repo.path, env: env, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _} -> {:error, output}
    end
  end

  defp cmd!(repo, args, env \\ []) do
    case cmd(repo, args, env) do
      {:ok, output} -> output
      {:error, output} -> raise "git #{Enum.join(args, " ")} failed:\n#{output}"
    end
  end

  @spec hooks_path(Git.Repository.t()) :: String.t() | no_return
  def hooks_path(repo) do
    case Git.config(repo, ["core.hookspath"]) do
      {:error, error} ->
        handle_hooks_path_error(error)

      {:ok, path} ->
        hookspath = String.trim_trailing(path, "\n")

        if File.dir?(hookspath) do
          hookspath
        else
          raise """
          Could not find the directory configured as git hooks path #{inspect(path)}. Ensure the git core.hookspath is set correctly.
          """
        end
    end
  end

  defp handle_hooks_path_error(error) do
    with 1 <- error.code,
         true <- File.dir?(@default_githooks_path) do
      @default_githooks_path
    else
      false ->
        raise """
        Could not find the default git hooks path #{inspect(@default_githooks_path)}. Is this a git repo?
        """

      _ ->
        raise error.message
    end
  end
end
