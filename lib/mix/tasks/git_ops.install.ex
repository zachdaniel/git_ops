defmodule Mix.Tasks.GitOps.Install.Docs do
  @moduledoc false

  def short_doc do
    "Installs GitOps into a project."
  end

  def example do
    "mix igniter.install git_ops"
  end

  def long_doc do
    """
    #{short_doc()}

    ## Example

    ```bash
    #{example()}
    ```

    ## Switches

    - `--no-manage-readme` - Disables mangaging the package version in the README file.
    - `--no-manage-mix` - Disables mangaging the package version in the `mix.exs` file.
    """
  end
end

if !Application.compile_env(:git_ops, :no_igniter?) && Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.GitOps.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :git_ops,
        adds_deps: [],
        installs: [],
        example: __MODULE__.Docs.example(),
        only: [:dev],
        dep_opts: [runtime: false],
        positional: [],
        composes: [],
        schema: [
          manage_readme: :boolean,
          manage_mix: :boolean
        ],
        defaults: [manage_readme: true, manage_mix: true],
        aliases: [],
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      opts = igniter.args.options

      manage_mix? = opts[:manage_mix]
      manage_readme? = opts[:manage_readme]

      igniter
      |> Igniter.Project.Config.configure_new(
        "config.exs",
        :git_ops,
        [:mix_project],
        {:code, Sourceror.parse_string!("Mix.Project.get!()")}
      )
      |> Igniter.Project.Config.configure_new("config.exs", :git_ops, [:types],
        tidbit: [hidden?: true],
        important: [header: "Important Changes"]
      )
      |> Igniter.Project.Config.configure_new(
        "config.exs",
        :git_ops,
        [:github_handle_lookup?],
        true
      )
      |> Igniter.Project.Config.configure_new("config.exs", :git_ops, [:version_tag_prefix], "v")
      |> then(fn igniter ->
        if manage_mix? do
          Igniter.Project.MixProject.update(igniter, :project, [:version], fn zipper ->
            version_attribute_exists? =
              zipper
              |> Sourceror.Zipper.top()
              |> Igniter.Code.Module.move_to_attribute_definition(:version) == :error

            if version_attribute_exists? do
              zipper
              |> Igniter.Code.Common.replace_code("@version")
              |> Sourceror.Zipper.top()
              |> Sourceror.Zipper.move_to_cursor("""
              defmodule __ do
                use __
                __cursor__()
              end
              """)
              |> Igniter.Code.Common.add_code("@version \"#{zipper.node}\"", placement: :before)
            else
              zipper
            end
          end)
        else
          igniter
        end
      end)
      |> Igniter.Project.Config.configure(
        "config.exs",
        :git_ops,
        [:manage_mix_version?],
        manage_mix?
      )
      |> Igniter.Project.Config.configure(
        "config.exs",
        :git_ops,
        [:manage_readme_version],
        manage_readme?
      )
      |> Igniter.Project.Config.configure_new(
        "config.exs",
        :git_ops,
        [:mix_project],
        Sourceror.parse_string!("Mix.Project.get!()")
      )
      |> Igniter.add_notice("""
      GitOps has been installed. To create the first release:

        mix git_ops.release --initial

      On subsequent releases, use:

        mix git_ops.release

      """)
    end
  end
else
  defmodule Mix.Tasks.GitOps.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'git_ops.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
