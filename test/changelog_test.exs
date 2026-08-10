defmodule GitOps.Test.ChangelogTest do
  use ExUnit.Case

  alias GitOps.Changelog

  setup context do
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

    if !context[:no_rm_on_exit] do
      on_exit(fn -> File.rm!(changelog) end)
    end

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

  @tag :no_rm_on_exit
  test "initializing with dry_run doesen't create the changelog file", context do
    changelog = context.changelog

    Changelog.initialize(changelog, dry_run: true)

    assert_raise File.Error, ~r/no such file or directory/, fn ->
      assert File.read!(changelog)
    end
  end

  test "writing commits to changefile works correctly", context do
    changelog = context.changelog

    Changelog.initialize(changelog)

    changes = Changelog.write(changelog, context.commits, "0.1.0", "0.2.0")

    assert String.length(changes) > 0
  end

  test "sections appear in section_order, not group order", context do
    changelog = context.changelog

    Changelog.initialize(changelog)

    commits = [
      %GitOps.Commit{message: "chore: tidy", type: "chore", breaking?: false},
      %GitOps.Commit{message: "docs: explain", type: "docs", breaking?: false},
      %GitOps.Commit{message: "fix: repair", type: "fix", breaking?: false},
      %GitOps.Commit{message: "feat: shiny", type: "feat", breaking?: false}
    ]

    Application.put_env(:git_ops, :types,
      chore: [header: "Other Changes", hidden?: false],
      docs: [header: "Documentation", hidden?: false]
    )

    on_exit(fn -> Application.delete_env(:git_ops, :types) end)

    changes = Changelog.write(changelog, commits, "0.1.0", "0.2.0")

    positions =
      for header <- ["Features", "Bug Fixes", "Documentation", "Other Changes"] do
        {position, _} = :binary.match(changes, header)
        {position, header}
      end

    assert positions == Enum.sort(positions)
  end

  test "writing with dry_run produces changes that aren't written", context do
    changelog = context.changelog

    Changelog.initialize(changelog)

    original_contents = File.read!(changelog)

    changes = Changelog.write(changelog, context.commits, "0.1.0", "0.2.0", dry_run: true)

    assert String.length(changes) > 0

    assert File.read!(changelog) == original_contents
  end
end
