defmodule Mix.Tasks.GitOps.CheckMessage do
  use Mix.Task

  @shortdoc "Check if a file's content follows the Conventional Commits spec"

  @moduledoc """
  Validates a commit message against the Conventional Commits specification.

  Check a file containing a commit message using:

      mix git_ops.check_message <path/to/file>
      
  or to check the most recent commit on the current branch:
    
      mix git_ops.check_message --head

  Logs an error if the commit message is not parse-able.

  See https://www.conventionalcommits.org/en/v1.0.0/ for more details on Conventional Commits.
  """

  alias GitOps.Commit
  alias GitOps.Config

  @doc false
  def run(["--head"]) do
    message =
      Config.repository_path()
      |> Git.init!()
      |> Git.log!(["-1", "--format=%s"])

    validate(message)
  end

  def run([path]) do
    # Full paths do not need to be wrapped with repo root
    path =
      if path == Path.absname(path) do
        path
      else
        Path.join(Config.repository_path(), path)
      end

    path
    |> File.read!()
    |> validate()
  end

  def run(_), do: error_exit("Invalid usage. See `mix help git_ops.check_message`")

  @spec error_exit(String.t()) :: no_return
  defp error_exit(message), do: raise(Mix.Error, message: message)

  defp validate(message) do
    case Commit.parse(message) do
      {:ok, _} ->
        :ok

      :error ->
        types = Config.types()

        not_hidden_types =
          types
          |> Enum.reject(fn {_type, opts} -> opts[:hidden?] end)
          |> Enum.map_join("|", fn {type, _} -> type end)

        hidden_types =
          types
          |> Enum.filter(fn {_type, opts} -> opts[:hidden?] end)
          |> Enum.map_join("|", fn {type, _} -> type end)

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
end
