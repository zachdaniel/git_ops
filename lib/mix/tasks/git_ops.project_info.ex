defmodule Mix.Tasks.GitOps.ProjectInfo do
  use Mix.Task

  @shortdoc "Return information about the project."

  @moduledoc """
  A handy helper which prints out the app name, version number and valid message types.

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

    types = Config.type_keys()

    project =
      Config.mix_project().project()
      |> Keyword.merge(types: types)

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
    {name, version, types} = extract_info_from_project(project)

    IO.write("[app]\nname = #{name}\nversion = #{version}\ntypes = \"#{types}\"\n")
  end

  defp format_json(project, _opts) do
    {name, version, types} = extract_info_from_project(project)

    IO.write(~s|{"app":{"name":"#{name}","version":"#{version}","types":"#{types}"}}\n|)
  end

  defp format_github_actions(project, _opts) do
    {name, version, types} = extract_info_from_project(project)

    System.fetch_env!("GITHUB_OUTPUT")
    |> File.write("app_name=#{name}\napp_version=#{version}\napp_types=\"#{types}\"\n", [:append])
  end

  defp format_shell(project, _opts) do
    {name, version, types} = extract_info_from_project(project)

    IO.write(
      ~s|export APP_NAME="#{name}"\nexport APP_VERSION="#{version}"\nexport APP_TYPES="#{types}"\n|
    )
  end

  defp format_dotenv(project, _opts) do
    {name, version, types} = extract_info_from_project(project)

    IO.write(~s|APP_NAME="#{name}"\nAPP_VERSION="#{version}"\nAPP_TYPES="#{types}"\n|)
  end

  defp extract_info_from_project(project) do
    %{app: name, version: version, types: types} =
      project
      |> Keyword.take(~w[app version types]a)
      |> Enum.into(%{})

    {name, version, types}
  end
end
