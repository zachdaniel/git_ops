defmodule GitOps.Git do
  def init!() do
    Git.init!(File.cwd!())
  end

  def tag!(repo, current_version) do
    Git.tag!(repo, current_version)
  end

  def get_initial_commits!(repo) do
    messages =
      repo
      |> Git.log!(["--format=%B--gitops--"])
      |> String.split("--gitops--")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&Kernel.==(&1, ""))

    ["chore(GitOps): Add changelog using git_ops." | messages]
  end

  def get_commits_since_last_version!(repo) do
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
    |> Git.log!(["#{most_recent_tag}..HEAD", "--format=%B--gitops--"])
    |> String.split("--gitops--")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&Kernel.==(&1, ""))
  end
end
