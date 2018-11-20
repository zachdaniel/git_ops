defmodule GitOps.Test.ChangelogTest do
  use ExUnit.Case

  alias GitOps.Changelog

  test "initialize with existing changelog raises" do
    changelog = "./TEST_CHANGELOG.md"

    File.write!(changelog, "")

    try do
      assert_raise RuntimeError, ~r/File already exists:/, fn ->
        Changelog.initialize(changelog)
      end
    after
      File.rm!(changelog)
    end
  end

  test "initialize creates non-empty changelog file" do
    changelog = "./TEST_CHANGELOG.md"

    try do
      Changelog.initialize(changelog)

      assert File.read!(changelog) != ""
    after
      File.rm!(changelog)
    end
  end

  test "writing commits to changefile works correctly" do
    changelog = "./TEST_CHANGELOG.md"

    commits = [
      %GitOps.Commit{
        body: nil,
        breaking?: false,
        footer: nil,
        message: "feat: New feature",
        scope: nil,
        type: "feat"
      },
      %GitOps.Commit{
        body: nil,
        breaking?: false,
        footer: nil,
        message: "fix: Fix that new feature",
        scope: nil,
        type: "fix"
      }
    ]

    try do
      Changelog.initialize(changelog)

      old_content =
        changelog
        |> File.read!()
        |> String.length()

      Changelog.write(changelog, commits, "0.1.0", "0.2.0")

      assert String.length(File.read!(changelog)) > old_content
    after
      File.rm!(changelog)
    end
  end
end
