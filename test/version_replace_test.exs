defmodule GitOps.Test.VersionReplaceTest do
  use ExUnit.Case

  alias GitOps.VersionReplace

  def readme_contents(version) do
    """
    ## Installation

    ```elixir
    def deps do
      [
        {:git_ops, "~> #{version}", only: [:dev]}
      ]
    end
    ```
    ...

    ```elixir
    {:git_ops, "~> #{version}", only: [:dev]}
    ```
    """
  end

  def package_json_contents(version) do
    """
    {
      "version": "#{version}"
    }
    """
  end

  setup do
    readme = "TEST_README.md"
    version = "0.1.1"

    readme_contents = readme_contents(version)

    File.write!(readme, readme_contents)

    package_json = "package.json"
    File.write!(package_json, package_json_contents(version))

    on_exit(fn ->
      File.rm!(readme)
      File.rm!(package_json)
    end)

    %{readme: readme, package_json: package_json, version: version}
  end

  test "that README gets written to properly", context do
    readme = context.readme
    version = context.version
    new_version = "1.0.0"

    VersionReplace.update_readme(readme, version, new_version)

    assert File.read!(readme) == readme_contents(new_version)
  end

  test "that README changes are not written with dry_run", context do
    readme = context.readme
    version = context.version
    new_version = "1.0.0"

    VersionReplace.update_readme(readme, version, new_version, dry_run: true)

    assert File.read!(readme) == readme_contents(version)
  end

  test "custom replace/pattern", context do
    readme = context.package_json
    version = context.version
    new_version = "1.0.0"

    VersionReplace.update_readme(
      {readme, fn v -> "\"version\": \"#{v}\"" end, fn v -> "\"version\": \"#{v}\"" end},
      version,
      new_version
    )

    assert File.read!(readme) == package_json_contents(new_version)
  end
end
