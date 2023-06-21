# Suppress actual of testing mix task
Mix.shell(Mix.Shell.Process)

defmodule GitOps.Mix.Tasks.Test.ProjectInfoTest do
  use ExUnit.Case
  alias Mix.Tasks.GitOps.ProjectInfo
  import ExUnit.CaptureIO
  @moduledoc false

  setup _context do
    Application.put_env(:git_ops, :mix_project, GitOps.MixProject)

    version = GitOps.MixProject.project()[:version]

    {:ok, name: :git_ops, version: version}
  end

  describe "TOML format" do
    test "it is correctly formatted", %{name: name, version: version} do
      actual = run(["--format", "toml"])

      expected = """
      [app]
      name = #{name}
      version = #{version}
      """

      assert actual == expected
    end
  end

  describe "JSON format" do
    test "it is correctly formatted", %{name: name, version: version} do
      actual = run(["--format", "json"])

      expected = """
      {
        "app": {
          "name": "#{name}",
          "version": "#{version}"
        }
      }
      """

      # The output is has whitespace removed for brevity
      assert actual == "#{String.replace(expected, ~r/\s+/, "")}\n"
    end
  end

  describe "Github Actions format" do
    test "it correctly formats data to the ENV file", %{name: name, version: version} do
      file = "#{System.tmp_dir()}/test_github_actions_format"
      System.put_env("GITHUB_OUTPUT", file)

      run(["--format", "github-actions"])

      actual = File.read!(file)

      expected = """
      app_name=#{name}
      app_version=#{version}
      """

      assert actual == expected

      on_exit(fn -> File.rm!(file) end)
    end
  end

  describe "Shell format" do
    test "it is correctly formatted", %{name: name, version: version} do
      actual = run(["--format", "shell"])

      expected = """
      export APP_NAME="#{name}"
      export APP_VERSION="#{version}"
      """

      assert actual == expected
    end
  end

  describe "Dotenv format" do
    test "it is correctly formatted", %{name: name, version: version} do
      actual = run(["--format", "dotenv"])

      expected = """
      APP_NAME="#{name}"
      APP_VERSION="#{version}"
      """

      assert actual == expected
    end
  end

  def run(args) do
    capture_io(fn ->
      ProjectInfo.run(args)
    end)
  end
end
