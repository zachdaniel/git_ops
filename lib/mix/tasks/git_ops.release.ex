defmodule Mix.Tasks.GitOps.Release do
  use Mix.Task

  @shortdoc "Parses the commit log and writes any updates to the changelog"

  @doc false
  def run(args) do
    repo = Git.init(File.cwd!())

    IO.inspect(repo)

    path =
      :git_ops
      |> Application.get_env(:changelog_file)
      |> Path.expand()

    message = "No changelog file found. Shall I create it? (#{path})"

    unless File.exists?(path) || Mix.shell().yes?(message) do
      raise "File: #{path} did not exist, and was not allowed to be created automatically."
    end

    :ok
  end
end
