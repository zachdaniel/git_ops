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
        2 + |import_config "\#{config_env()}.exs"
      """)
      |> assert_has_patch("config/dev.exs", """
      3 |config :git_ops,
      4 |  mix_project: Mix.Project.get!(),
      5 |  types: [types: [tidbit: [hidden?: true], important: [header: "Important Changes"]]],
      6 |  version_tag_prefix: "v",
      7 |  manage_mix_verions?: true,
      8 |  manage_readme_version: true
      """)
    end

    test "opt out of managed files" do
      [app_name: :my_app, files: %{}]
      |> test_project()
      |> Igniter.compose_task("git_ops.install", ["--no-manage-readme", "--no-manage-mix"])
      |> assert_has_patch("config/dev.exs", """
      3 |config :git_ops,
      4 |  mix_project: Mix.Project.get!(),
      5 |  types: [types: [tidbit: [hidden?: true], important: [header: "Important Changes"]]],
      6 |  version_tag_prefix: "v",
      7 |  manage_mix_verions?: false,
      8 |  manage_readme_version: false
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
  end
end
