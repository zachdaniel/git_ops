# Suppress output of testing mix task
# Mix.shell(Mix.Shell.Process)

defmodule GitOps.Mix.Tasks.Test.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  describe "install" do
    test "patches configs" do
      config = """
      import Config
      """

      files = %{"config/config.exs" => config}

      [app_name: :my_app, files: files]
      |> test_project()
      |> Igniter.compose_task("git_ops.install", [])
      |> assert_has_patch("config/config.exs", """
      + |config :git_ops,
      + |  mix_project: Mix.Project.get!(),
      + |  types: [tidbit: [hidden?: true], important: [header: "Important Changes"]],
      + |  github_handle_lookup?: true,
      + |  version_tag_prefix: "v",
      + |  manage_mix_version?: true,
      + |  manage_readme_version: true
      """)
    end

    test "opt out of managed files" do
      [app_name: :my_app, files: %{}]
      |> test_project()
      |> Igniter.compose_task("git_ops.install", ["--no-manage-readme", "--no-manage-mix"])
      |> assert_has_patch("config/config.exs", """
      |config :git_ops,
      |  mix_project: Mix.Project.get!(),
      |  types: [tidbit: [hidden?: true], important: [header: "Important Changes"]],
      |  github_handle_lookup?: true,
      |  version_tag_prefix: "v",
      |  manage_mix_version?: false,
      |  manage_readme_version: false
      """)
    end

    test "patches project version" do
      [app_name: :my_app, files: %{}]
      |> test_project()
      |> Igniter.compose_task("git_ops.install", [])
      |> assert_has_patch("mix.exs", """
      2  2   |  use Mix.Project
      3  3   |
         4 + |  @version "0.1.0"
      4  5   |  def project do
      5  6   |    [
      6  7   |      app: :my_app,
      7    - |      version: "0.1.0",
         8 + |      version: @version,
      """)
    end

    test "skips project version patch if exists" do
      mix = """
      defmodule Elixir.MyApp.MixProject do
        use Mix.Project

        @version "0.1.0"
        def project do
          [
            app: :my_app,
            version: @version,
            elixir: "~> 1.17",
            start_permanent: Mix.env() == :prod,
            deps: deps()
          ]
        end

        # Run "mix help compile.app" to learn about applications.
        def application do
          [
            extra_applications: [:logger]
          ]
        end

        # Run "mix help deps" to learn about dependencies.
        defp deps do
          [
            # {:dep_from_hexpm, "~> 0.3.0"},
            # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
          ]
        end
      end
      """

      [app_name: :my_app, files: %{"mix.exs" => mix}]
      |> test_project()
      # |> dbg(structs: false)
      |> Igniter.compose_task("git_ops.install", [])
      |> assert_unchanged("mix.exs")
    end
  end
end
