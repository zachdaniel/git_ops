defmodule Mix.Tasks.GitOps.ProjectInfo do
  use Mix.Task

  @shortdoc "Return information about the project."

  @moduledoc """
  A handy helper which prints out the app name and version number.

  May be useful in your CI system.

      mix git_ops.project_info

  ## Switches:

  * `--format|-f` selects the output format. Currently suported output formats
    are `json`, `toml`, `github-actions`, `shell` and `dotenv`.
  """

  alias GitOps.Config

  @default_opts [format: "toml"]

  @doc false
  def run(args) do
    opts =
      @default_opts
      |> parse(args)

    project = Config.mix_project().project()

    opts
    |> Keyword.get(:format)
    |> String.downcase()
    |> case do
      "toml" ->
        format_toml(project, opts)

      "json" ->
        format_json(project, opts)

      "github-actions" ->
        format_github_actions(project, opts)

      "shell" ->
        format_shell(project, opts)

      "dotenv" ->
        format_dotenv(project, opts)

      format ->
        raise "Invalid format `#{inspect(format)}`.  Valid formats are `json`, `toml`, `github-actions`, `shell` and `dotenv`."
    end
  end

  defp parse(defaults, args) do
    {opts, _} =
      args
      |> OptionParser.parse!(strict: [format: :string], aliases: [f: :format])

    defaults
    |> Keyword.merge(opts)
  end

  defp format_toml(project, _opts) do
    {name, version} = extract_name_and_version_from_project(project)

    IO.write("[app]\nname = #{name}\nversion = #{version}\n")
  end

  defp format_json(project, _opts) do
    {name, version} = extract_name_and_version_from_project(project)

    IO.write(~s|{"app":{"name":"#{name}","version":"#{version}"}}\n|)
  end

  defp format_github_actions(project, _opts) do
    {name, version} = extract_name_and_version_from_project(project)

    IO.write("::set-output name=app_name::#{name}\n::set-output name=app_version::#{version}\n")
  end

  defp format_shell(project, _opts) do
    {name, version} = extract_name_and_version_from_project(project)

    IO.write(~s|export APP_NAME="#{name}"\nexport APP_VERSION="#{version}"\n|)
  end

  defp format_dotenv(project, _opts) do
    {name, version} = extract_name_and_version_from_project(project)

    IO.write(~s|APP_NAME="#{name}"\nAPP_VERSION="#{version}"\n|)
  end

  defp extract_name_and_version_from_project(project) do
    %{app: name, version: version} =
      project
      |> Keyword.take(~w[app version]a)
      |> Enum.into(%{})

    {name, version}
  end
end
