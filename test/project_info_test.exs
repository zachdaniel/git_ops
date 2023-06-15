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
    test "it is correctly formatted", %{name: name, version: version} do
      actual = run(["--format", "github-actions"])

      expected = """
      echo "app_name=#{name}" >> $GITHUB_OUTPUT
      echo "app_version=#{version}" >> $GITHUB_OUTPUT
      """

      assert actual == expected
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
