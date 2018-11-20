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

  setup_all do
    readme = "TEST_README.md"
    readme_contents = readme_contents("0.1.1")

    File.write!(readme, readme_contents)

    on_exit(fn -> File.rm!(readme) end)

    %{readme: readme}
  end

  test "that README gets written to properly", context do
    readme = context.readme

    VersionReplace.update_readme(readme, "0.1.1", "1.0.0")

    assert File.read!(readme) == readme_contents("1.0.0")
  end

  test "that README changes are not written with dry_run", context do
    readme = context.readme

    VersionReplace.update_readme(readme, "0.1.1", "1.0.0", dry_run: true)

    assert File.read!(readme) == readme_contents("1.0.0")
  end
end
