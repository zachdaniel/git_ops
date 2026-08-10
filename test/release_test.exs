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
      Application.put_env(:git_ops, :github_handle_lookup?, false)

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
      Application.put_env(:git_ops, :github_handle_lookup?, false)

      on_exit(fn -> File.rm!(changelog) end)

      %{changelog: changelog}
    end

    test "release with dry run works properly", context do
      File.write!(context.changelog, "")

      Release.run(["--dry-run", "--force-patch"])
    end
  end

  describe "with version_source :tags" do
    setup do
      changelog = "TEST_CHANGELOG.md"

      Application.put_env(:git_ops, :mix_project, nil)
      Application.put_env(:git_ops, :repository_url, "repo/url.git")
      Application.put_env(:git_ops, :manage_mix_version?, false)
      Application.put_env(:git_ops, :changelog_file, changelog)
      Application.put_env(:git_ops, :manage_readme_version, false)
      Application.put_env(:git_ops, :types, custom: [header: "Custom"], docs: [hidden?: false])
      Application.put_env(:git_ops, :version_tag_prefix, "v")
      Application.put_env(:git_ops, :github_handle_lookup?, false)
      Application.put_env(:git_ops, :version_source, :tags)

      on_exit(fn ->
        Application.delete_env(:git_ops, :version_source)
        File.rm!(changelog)
      end)

      %{changelog: changelog}
    end

    test "release with dry run works without a mix project", context do
      File.write!(context.changelog, "")

      Release.run(["--dry-run", "--force-patch"])
    end
  end

  describe "with version_source {:file, path, pattern}" do
    setup do
      changelog = "TEST_CHANGELOG.md"
      version_file = "TEST_VERSION.json"

      Application.put_env(:git_ops, :mix_project, nil)
      Application.put_env(:git_ops, :repository_url, "repo/url.git")
      Application.put_env(:git_ops, :manage_mix_version?, false)
      Application.put_env(:git_ops, :changelog_file, changelog)
      Application.put_env(:git_ops, :manage_readme_version, false)
      Application.put_env(:git_ops, :types, custom: [header: "Custom"], docs: [hidden?: false])
      Application.put_env(:git_ops, :version_tag_prefix, "v")
      Application.put_env(:git_ops, :github_handle_lookup?, false)

      Application.put_env(
        :git_ops,
        :version_source,
        {:file, version_file, ~r/"version": "([^"]+)"/}
      )

      on_exit(fn ->
        Application.delete_env(:git_ops, :version_source)
        File.rm!(changelog)
        File.rm!(version_file)
      end)

      %{changelog: changelog, version_file: version_file}
    end

    test "release with dry run reads the version from the file", context do
      File.write!(context.changelog, "")
      File.write!(context.version_file, ~s({"name": "test", "version": "0.1.0"}\n))

      Release.run(["--dry-run", "--force-patch"])
    end

    test "release fails when the pattern does not match", context do
      File.write!(context.changelog, "")
      File.write!(context.version_file, ~s({"name": "test"}\n))

      assert_raise Mix.Error, ~r/did not match the configured version pattern/, fn ->
        Release.run(["--dry-run", "--force-patch"])
      end
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
      Application.put_env(:git_ops, :github_handle_lookup?, false)

      on_exit(fn -> File.rm!(changelog) end)

      %{changelog: changelog}
    end

    test "release with dry run works properly", context do
      File.write!(context.changelog, "")

      Release.run(["--dry-run", "--force-patch"])
    end
  end
end
