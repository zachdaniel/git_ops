defmodule Mix.Tasks.GitOps.MsgHook do
  use Mix.Task

  @shortdoc "A git commit-msg hook for validating conventional commit messages"

  @moduledoc """
  Validates that the content of the given file path follows the Conventional Commits specification.
  Also can be installed as a git commit-msg hook to automatically validate git commit messages

      mix git_ops.msg_hook <command> [args]

  ## Commands:

  * `check` - Validates that the content of the given file path follows the Conventional Commits
    specification:
      ```
      mix git_ops.msg_hook check <path/to/commit/message/file>
      ```
    Logs an error if the commit message is not parse-able.

    For more information on Conventional Commits, see the specification here:
    https://www.conventionalcommits.org/en/v1.0.0/

  * `install` - Installs itself as a git commit-msg hook to automatically check the commit message:
      ```
      mix git_ops.msg_hook install
      ```

  """

  alias GitOps.Commit

  @doc false
  def run(["check", path]) do
    message = File.read!(path)

    case Commit.parse(message) do
      {:ok, _} ->
        :ok

      :error ->
        error_exit("""
        Not a valid Conventional Commit message:\n#{message}

        See https://www.conventionalcommits.org/en/v1.0.0/ for details.
        """)
    end
  end

  def run(["install"]) do
    :ok
  end

  def run(_), do: error_exit("Invalid mix git_ops.msg command. See `mix help git_ops.msg_hook`")

  @spec error_exit(String.t()) :: no_return
  defp error_exit(message), do: raise(Mix.Error, message: message)
end
