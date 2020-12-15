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

  describe "Github Actions actual format" do
    test "it is correctly formatted", %{name: name, version: version} do
      actual = run(["--format", "github-actions"])

      expected = """
      ::set-output name=app_name::#{name}
      ::set-output name=app_version::#{version}
      """

      assert actual == expected
    end
  end

  describe "Shell actual format" do
    test "it is correctly formatted", %{name: name, version: version} do
      actual = run(["--format", "shell"])

      expected = """
      export APP_NAME="#{name}"
      export APP_VERSION="#{version}"
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
