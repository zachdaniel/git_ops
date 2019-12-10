defmodule Mix.Tasks.GitOps.CheckMessage do
  use Mix.Task

  @shortdoc "Check if a file's content follows the Conventional Commits spec"

  @moduledoc """
  Receives a file path and validates if it's content follows the Conventional Commits specification.

      mix git_ops.check_message <path/to/file>

  Logs an error if the commit message is not parse-able.

  For more information on Conventional Commits, see the specification here:
  https://www.conventionalcommits.org/en/v1.0.0/
  """

  alias GitOps.Commit
  alias GitOps.Git

  @commit_msg_hook_name "commit-msg"

  @doc false
  def run([path]) do
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

  def run(_), do: error_exit("Invalid usage. See `mix help git_ops.check_message`")

  @spec error_exit(String.t()) :: no_return
  defp error_exit(message), do: raise(Mix.Error, message: message)
end
