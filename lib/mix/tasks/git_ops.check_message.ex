defmodule Mix.Tasks.GitOps.CheckMessage do
  use Mix.Task

  @shortdoc "Check if a file's content follows the Conventional Commits spec"

  @moduledoc """
  Receives a file path and validates if it's content follows the Conventional Commits specification.

      mix git_ops.check_message <path/to/file>

  Logs an error if the commit message is not parse-able.

  See https://www.conventionalcommits.org/en/v1.0.0/ for more details on Conventional Commits.
  """

  alias GitOps.Commit
  alias GitOps.Config

  @doc false
  def run([path]) do
    message = File.read!(path)

    case Commit.parse(message) do
      {:ok, _} ->
        :ok

      :error ->
        types = Config.types()

        not_hidden_types =
          types
          |> Enum.filter(fn {_type, opts} -> !opts[:hidden?] end)
          |> Enum.map(fn {type, _} -> type end)
          |> Enum.join("|")

        hidden_types =
          types
          |> Enum.filter(fn {_type, opts} -> opts[:hidden?] end)
          |> Enum.map(fn {type, _} -> type end)
          |> Enum.join("|")

        all_types = "#{not_hidden_types}|#{hidden_types}"

        error_exit("""
        Not a valid Conventional Commit message:
        #{message}

        The Conventionl Commit message format is:

          <type>[optional scope][optional !]: <description>

          [optional body]

          [optional footer(s)]

        Where:
          • <type> is one of #{all_types}
          • A bugfix is specified by type `fix`
          • A new feature is specified by type `feat`
          • A breaking change is specified by either `!` after <type>[optional scope] or by a
            `BREAKING CHANGE: <description>` footer.

        See https://www.conventionalcommits.org/en/v1.0.0/ for more details.
        """)
    end
  end

  def run(_), do: error_exit("Invalid usage. See `mix help git_ops.check_message`")

  @spec error_exit(String.t()) :: no_return
  defp error_exit(message), do: raise(Mix.Error, message: message)
end
