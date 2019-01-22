# Suppress output of testing mix task
Mix.shell(Mix.Shell.Process)

defmodule GitOps.Mix.Tasks.Test.ReleaseTest do
  use ExUnit.Case

  alias Mix.Tasks.GitOps.Release

  describe "with version_tag_prefix" do
    setup do
      changelog = "TEST_CHANGELOG.md"

      Application.put_env(:git_ops, :mix_project, GitOps.MixProject)
      Application.put_env(:git_ops, :repository_url, "repo/url.git")
      Application.put_env(:git_ops, :manage_mix_version?, true)
      Application.put_env(:git_ops, :changelog_file, changelog)
      Application.put_env(:git_ops, :manage_readme_version, true)
      Application.put_env(:git_ops, :types, custom: [header: "Custom"], docs: [hidden?: false])
      Application.put_env(:git_ops, :version_tag_prefix, "v")

      on_exit(fn -> File.rm!(changelog) end)

      %{changelog: changelog}
    end

    test "release with dry run works properly", context do
      File.write!(context.changelog, "")

      Release.run(["--dry-run", "--force-patch"])
    end
  end

  describe "without version_tag_prefix" do
    setup do
      changelog = "TEST_CHANGELOG.md"

      Application.put_env(:git_ops, :mix_project, GitOps.MixProject)
      Application.put_env(:git_ops, :repository_url, "repo/url.git")
      Application.put_env(:git_ops, :manage_mix_version?, true)
      Application.put_env(:git_ops, :changelog_file, changelog)
      Application.put_env(:git_ops, :manage_readme_version, true)
      Application.put_env(:git_ops, :types, custom: [header: "Custom"], docs: [hidden?: false])

      on_exit(fn -> File.rm!(changelog) end)

      %{changelog: changelog}
    end

    test "release with dry run works properly", context do
      File.write!(context.changelog, "")

      Release.run(["--dry-run", "--force-patch"])
    end
  end

  describe "with empty version_tag_prefix" do
    setup do
      changelog = "TEST_CHANGELOG.md"

      Application.put_env(:git_ops, :mix_project, GitOps.MixProject)
      Application.put_env(:git_ops, :repository_url, "repo/url.git")
      Application.put_env(:git_ops, :manage_mix_version?, true)
      Application.put_env(:git_ops, :changelog_file, changelog)
      Application.put_env(:git_ops, :manage_readme_version, true)
      Application.put_env(:git_ops, :types, custom: [header: "Custom"], docs: [hidden?: false])
      Application.put_env(:git_ops, :version_tag_prefix, "")

      on_exit(fn -> File.rm!(changelog) end)

      %{changelog: changelog}
    end

    test "release with dry run works properly", context do
      File.write!(context.changelog, "")

      Release.run(["--dry-run", "--force-patch"])
    end
  end
end
