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

  def mix_contents(version) do
    """
    defmodule MyApp.MixProject do
      @version "#{version}"

      def project do
        [version: @version]
      end
    end
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
    mix_file = "TEST_MIX.exs"
    package_json = "package.json"
    version = "0.1.1"

    File.write!(readme, readme_contents(version))
    File.write!(mix_file, mix_contents(version))
    File.write!(package_json, package_json_contents(version))

    on_exit(fn ->
      File.rm!(readme)
      File.rm!(mix_file)
      File.rm!(package_json)
    end)

    %{readme: readme, mix_file: mix_file, package_json: package_json, version: version}
  end

  test "string-style replacement updates README properly", context do
    managed_file = {context.readme, fn v -> ", \"~> #{v}\"" end, fn v -> ", \"~> #{v}\"" end}
    VersionReplace.update_managed_file(managed_file, context.version, "1.0.0")
    assert File.read!(context.readme) == readme_contents("1.0.0")
  end

  test "mix-style replacement updates version attribute", context do
    managed_file =
      {context.mix_file, fn v -> "@version \"#{v}\"" end, fn v -> "@version \"#{v}\"" end}

    VersionReplace.update_managed_file(managed_file, context.version, "1.0.0")
    assert File.read!(context.mix_file) == mix_contents("1.0.0")
  end

  test "changes are not written with dry_run", context do
    managed_file = {context.readme, fn v -> ", \"~> #{v}\"" end, fn v -> ", \"~> #{v}\"" end}
    VersionReplace.update_managed_file(managed_file, context.version, "1.0.0", dry_run: true)
    assert File.read!(context.readme) == readme_contents(context.version)
  end

  test "custom replace/pattern functions", context do
    managed_file =
      {context.package_json, fn v -> "\"version\": \"#{v}\"" end,
       fn v -> "\"version\": \"#{v}\"" end}

    VersionReplace.update_managed_file(managed_file, context.version, "1.0.0")
    assert File.read!(context.package_json) == package_json_contents("1.0.0")
  end
end
