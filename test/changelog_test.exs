defmodule GitOps.Test.ChangelogTest do
  use ExUnit.Case

  alias GitOps.Changelog

  setup do
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

    on_exit fn -> File.rm!(changelog) end

    %{changelog: changelog, commits: commits}
  end

  test "initialize with existing changelog raises", context do
    changelog = context.changelog

    File.write!(changelog, "")

    assert_raise RuntimeError, ~r/File already exists:/, fn ->
      Changelog.initialize(changelog)
    end
  end

  test "initialize creates non-empty changelog file", context do
    changelog = context.changelog

    Changelog.initialize(changelog)

    assert File.read!(changelog) != ""
  end

  test "writing commits to changefile works correctly", context do
    changelog = context.changelog

    Changelog.initialize(changelog)

    changes = Changelog.write(changelog, context.commits, "0.1.0", "0.2.0")

    assert String.length(changes) > 0
  end

  test "writing with dry_run produces changes that aren't written", context do
    changelog = context.changelog

    Changelog.initialize(changelog)

    original_contents = File.read!(changelog)

    changes = Changelog.write(changelog, context.commits, "0.1.0", "0.2.0", [dry_run: true])

    assert String.length(changes) > 0

    assert File.read!(changelog) == original_contents
  end
end
