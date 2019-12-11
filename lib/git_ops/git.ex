defmodule GitOps.Git do
  @moduledoc """
  Helper functions for working with `Git` and fetching the tags/commits we care about.
  """

  @default_githooks_path ".git/hooks"

  @spec init!() :: Git.Repository.t()
  def init!() do
    Git.init!(File.cwd!())
  end

  @spec add!(Git.Repositor.t(), [String.t()]) :: String.t()
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
      |> Git.tag!()
      |> String.split("\n")

    if Enum.empty?(tags) do
      raise """
      Could not find an appropriate semver tag in git history. Ensure that you have initialized the project and commited the result.
      """
    else
      tags
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
      {:error, %Git.Error{message: "", code: 1}} ->
        # no custom config for core.hookspath
        if File.dir?(@default_githooks_path) do
          @default_githooks_path
        else
          raise """
          Could not find the default git hooks path #{inspect(@default_githooks_path)}. Is this a git repo?
          """
        end

      {:error, %Git.Error{message: message}} ->
        raise message

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
end
