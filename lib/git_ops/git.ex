defmodule GitOps.Git do
  @moduledoc """
  Helper functions for working with `Git` and fetching the tags/commits we care about.
  """

  @default_githooks_path ".git/hooks"

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

  @spec get_initial_commits!(Git.Repository.t()) :: [String.t()]
  def get_initial_commits!(repo) do
    messages =
      repo
      |> Git.log!(["--format=%B--gitops--"])
      |> String.split("--gitops--")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&Kernel.==(&1, ""))

    ["chore(GitOps): Add changelog using git_ops." | messages]
  end

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

  @spec commit_messages_since_tag(Git.Repository.t(), String.t()) :: [String.t()]
  def commit_messages_since_tag(repo, tag) do
    repo
    |> Git.log!(["#{tag}..HEAD", "--format=%B--gitops--"])
    |> String.split("--gitops--")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&Kernel.==(&1, ""))
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
