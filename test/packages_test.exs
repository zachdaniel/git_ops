defmodule GitOps.Mix.Tasks.Test.PackagesTest do
  use ExUnit.Case

  import GitOps.Test.MonorepoFixture

  alias GitOps.Config
  alias Mix.Tasks.GitOps.Release

  @config %{
    "repository_url" => "https://github.com/example/mono",
    "packages" => %{
      "pkg_a" => %{
        "managed_files" => [%{"path" => "package.json", "type" => "json"}]
      },
      "pkg_b" => %{
        "managed_files" => [%{"path" => "version.txt", "type" => "raw"}],
        "patch_on_any_change" => true,
        "depends_on" => ["shared"]
      },
      "pkg_a/nested" => %{
        "managed_files" => [%{"path" => "version.txt", "type" => "raw"}]
      }
    },
    "linked_packages" => [["pkg_b", "pkg_a/nested"]]
  }

  setup do
    dir =
      Path.join(
        System.tmp_dir!(),
        "git_ops_packages_test_#{System.unique_integer([:positive])}"
      )

    isolate_in!(dir)
    init_repo!(dir)

    File.write!(Path.join(dir, "git_ops.json"), Jason.encode!(@config))
    write!(dir, "pkg_a/package.json", ~s({\n  "name": "a",\n  "version": "0.1.0"\n}\n))
    write!(dir, "pkg_a/nested/version.txt", "0.1.0\n")
    write!(dir, "pkg_b/version.txt", "0.1.0\n")

    git!(dir, ["add", "."])
    git!(dir, ["commit", "-q", "-m", "chore: initial commit"])
    git!(dir, ["tag", "pkg_a-v0.1.0"])
    git!(dir, ["tag", "nested-v0.1.0"])
    git!(dir, ["tag", "pkg_b-v0.1.0"])

    %{dir: dir}
  end

  test "packages/0 builds packages from git_ops.json" do
    packages = Config.packages()

    assert Enum.map(packages, & &1.path) == ["pkg_a", "pkg_a/nested", "pkg_b"]

    pkg_a = Enum.find(packages, &(&1.path == "pkg_a"))
    assert pkg_a.name == "pkg_a"
    assert pkg_a.prefix == "pkg_a-v"
    assert pkg_a.changelog_file == "pkg_a/CHANGELOG.md"
    assert pkg_a.version_source == :tags
    assert [{"pkg_a/package.json", _, _}] = pkg_a.managed_files
    refute pkg_a.patch_on_any_change?

    pkg_b = Enum.find(packages, &(&1.path == "pkg_b"))
    assert pkg_b.patch_on_any_change?
  end

  test "releases only packages whose paths have releasable commits", %{dir: dir} do
    commit!(dir, "pkg_a/lib.js", "code\n", "feat: shiny feature")

    Release.run(["--yes"])

    tags = git!(dir, ["tag", "--list"])
    assert tags =~ "pkg_a-v0.2.0"
    refute tags =~ "pkg_b-v0.1.1"

    assert File.read!(Path.join(dir, "pkg_a/package.json")) =~ ~s("version": "0.2.0")
    changelog = File.read!(Path.join(dir, "pkg_a/CHANGELOG.md"))
    assert changelog =~ "## [0.2.0]"
    assert changelog =~ "shiny feature"
    assert changelog =~ "compare/pkg_a-v0.1.0...pkg_a-v0.2.0"
  end

  test "chore commits release only packages with patch_on_any_change", %{dir: dir} do
    commit!(dir, "pkg_a/tool.js", "code\n", "chore: tweak tooling")
    commit!(dir, "pkg_b/tool.txt", "text\n", "chore: tweak other tooling")

    Release.run(["--yes"])

    tags = git!(dir, ["tag", "--list"])
    refute tags =~ "pkg_a-v0.1.1"
    assert tags =~ "pkg_b-v0.1.1"
    assert File.read!(Path.join(dir, "pkg_b/version.txt")) == "0.1.1\n"
  end

  test "nested package commits do not release the parent", %{dir: dir} do
    commit!(dir, "pkg_a/nested/lib.txt", "code\n", "fix: nested fix")

    Release.run(["--yes"])

    tags = git!(dir, ["tag", "--list"])
    assert tags =~ "nested-v0.1.1"
    refute tags =~ "pkg_a-v0.1.1"
  end

  test "linked packages release together at the same version", %{dir: dir} do
    commit!(dir, "pkg_a/nested/lib.txt", "code\n", "feat: nested feature")

    Release.run(["--yes"])

    tags = git!(dir, ["tag", "--list"])
    assert tags =~ "nested-v0.2.0"
    assert tags =~ "pkg_b-v0.2.0"
    assert File.read!(Path.join(dir, "pkg_b/version.txt")) == "0.2.0\n"
    assert File.read!(Path.join(dir, "pkg_b/CHANGELOG.md")) =~ "## [0.2.0]"
  end

  test "depends_on commits release the dependent with their changelog entries", %{dir: dir} do
    commit!(dir, "shared/util.txt", "code\n", "feat: shared feature")

    Release.run(["--yes"])

    tags = git!(dir, ["tag", "--list"])
    assert tags =~ "pkg_b-v0.2.0"
    refute tags =~ "pkg_a-v0.2.0"

    changelog = File.read!(Path.join(dir, "pkg_b/CHANGELOG.md"))
    assert changelog =~ "## [0.2.0]"
    assert changelog =~ "shared feature"
  end

  test "dry run changes nothing", %{dir: dir} do
    commit!(dir, "pkg_a/lib.js", "code\n", "feat: shiny feature")

    Release.run(["--dry-run"])

    tags = git!(dir, ["tag", "--list"])
    refute tags =~ "pkg_a-v0.2.0"
    assert File.read!(Path.join(dir, "pkg_a/package.json")) =~ ~s("version": "0.1.0")
    refute File.exists?(Path.join(dir, "pkg_a/CHANGELOG.md"))
  end
end
