defmodule GitOps.Test.ConfigTest do
  use ExUnit.Case

  alias GitOps.Config

  setup do
    Application.put_env(:git_ops, :mix_project, Project)
    Application.put_env(:git_ops, :repository_url, "repo/url.git")
    Application.put_env(:git_ops, :manage_mix_version?, false)
    Application.put_env(:git_ops, :changelog_file, "CUSTOM_CHANGELOG.md")
    Application.put_env(:git_ops, :manage_readme_version, true)
    Application.put_env(:git_ops, :types, custom: [header: "Custom"], docs: [hidden?: false])
    Application.put_env(:git_ops, :tags, [allowed: ["tag_1", "tag_2"], allow_untagged?: false])
    Application.put_env(:git_ops, :version_tag_prefix, "v")
  end

  test "mix_project returns correctly" do
    assert Config.mix_project() == Project
  end

  test "changelog_file custom returns custom file" do
    assert Config.changelog_file() == "CUSTOM_CHANGELOG.md"
  end

  test "changelog_file nil returns default" do
    Application.put_env(:git_ops, :changelog_file, nil)
    assert Config.changelog_file() == "CHANGELOG.md"
  end

  test "mix_project_check fails on project with no version" do
    Application.put_env(:git_ops, :mix_project, InvalidProject)

    assert_raise RuntimeError, ~r/mix_project must be configured/, fn ->
      Config.mix_project_check()
    end
  end

  test "mix_project_check fails on invalid changelog" do
    assert_raise RuntimeError, ~r/File: .+ did not exist/, fn ->
      Config.mix_project_check()
    end
  end

  test "mix_project_check succeeds with initial flag but no changelog file" do
    Config.mix_project_check(initial: true)
  end

  test "mix_project_check succeeds on valid project" do
    changelog = "CUSTOM_CHANGELOG.md"

    File.write!(changelog, "")

    try do
      Config.mix_project_check(nil)
    after
      File.rm!(changelog)
    end
  end

  test "repository_url returns correctly" do
    assert Config.repository_url() == "repo/url.git"
  end

  test "repository_path returns correctly" do
    assert Config.repository_path() == File.cwd!()
  end

  test "manage_mix_version? returns correctly" do
    assert Config.manage_mix_version?() == false
  end

  test "manage_readme_version true results in default README" do
    assert Config.manage_readme_version() == "README.md"
  end

  test "manage_readme_version custom results in custom file" do
    Application.put_env(:git_ops, :manage_readme_version, "CUSTOM_README.md")

    assert Config.manage_readme_version() == "CUSTOM_README.md"
  end

  test "manage_readme_version nil results in false" do
    Application.put_env(:git_ops, :manage_readme_version, nil)

    assert Config.manage_readme_version() == false
  end

  test "custom types configuration merges correctly" do
    types = Config.types()

    assert types["docs"][:hidden?] == false
    assert types["custom"][:header] == "Custom"
  end

  test "Allowed tags configuration returns correcly" do
    assert Config.allowed_tags() == ["tag_1", "tag_2"]
  end

  test "Allowed tags configuration returns :any if not set" do
    Application.delete_env(:git_ops, :tags)

    assert Config.allowed_tags() == :any
  end

  test "Allow untagged? configuration returns correcly" do
    assert Config.allow_untagged?() == false
  end

  test "Allow untagged? configuration returns true if not set" do
    Application.delete_env(:git_ops, :tags)

    assert Config.allow_untagged?() == true
  end

  test "custom prefixes returns correctly" do
    assert Config.prefix() == "v"
  end
end

defmodule Project do
  def project, do: [version: "0.1.0"]
end

defmodule InvalidProject do
  def project, do: nil
end
