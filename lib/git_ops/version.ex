defmodule GitOps.Version do
  def last_valid_non_rc_version(versions) do
    versions
    |> Enum.reverse()
    |> Enum.find(fn version ->
      match?({:ok, %{pre: []}}, Version.parse(version))
    end)
  end

  def determine_new_version(versions, commits, opts) do
    parsed =
      versions
      |> last_valid_non_rc_version()
      |> Version.parse!()

    rc? = opts[:rc]

    build = opts[:build]

    new_version =
      cond do
        Enum.any?(commits, &GitOps.Commit.breaking?/1) ->
          if opts[:no_major] do
            %{parsed | major: parsed.major, minor: parsed.minor + 1, patch: 0}
          else
            %{parsed | major: parsed.major + 1, minor: 0, patch: 0}
          end

        Enum.any?(commits, &GitOps.Commit.feature?/1) ->
          %{parsed | minor: parsed.minor + 1, patch: 0}

        Enum.any?(commits, &GitOps.Commit.fix?/1) || opts[:force_patch] ->
          %{parsed | patch: parsed.patch + 1}

        true ->
          parsed
      end

    pre_release =
      if rc? do
        versions
        |> last_pre_release_version_after(parsed)
        |> increment_rc!(new_version)
        |> List.wrap()
      else
        List.wrap(opts[:pre_release])
      end

    if versions_equal?(new_version, parsed) && build == parsed.build do
      raise """
      No changes should result in a new release version.

      Options:

      * If no fixes or features were added, then perhaps you don't need to release.
      * If a fix or feature commit was not correctly annotated, you could alter your git
        history to fix it and run this command again, or create an empty commit via
        `git commit --allow-empty` that contains an appropriate message.
      * If you don't care and want a new version, you can use `--force-patch` which
        will update the patch version regardless.
      * You can add build metadata using `--build` that will signify that something was
        unique about this build.
      """
    end

    new_version
    |> Map.put(:pre, pre_release)
    |> Map.put(:build, build)
    |> to_string()
  end

  def last_pre_release_version_after(versions, last_version) do
    Enum.find(versions, fn version ->
      case Version.parse(version) do
        {:ok, version} ->
          Version.compare(version, last_version) == :gt

        _ ->
          false
      end
    end)
  end

  defp increment_rc!(nil, _), do: "rc0"

  defp increment_rc!(last_pre_release_version, new_version) do
    parsed_pre_release = Version.parse!(last_pre_release_version)

    if versions_equal_no_pre?(parsed_pre_release, new_version) do
      parsed_pre_release
      |> Map.get(:pre)
      |> Enum.at(0)
      |> do_increment_rc!()
    else
      ["rc0"]
    end
  end

  defp do_increment_rc!(nil), do: "rc0"

  defp do_increment_rc!(rc = "rc" <> version) do
    case Integer.parse(version) do
      {int, ""} ->
        "rc#{int + 1}"

      :error ->
        raise "Found an rc version that could not be parsed: #{rc}"
    end
  end

  defp do_increment_rc!(rc) do
    raise "Found an rc version that could not be parsed: #{rc}"
  end

  defp versions_equal?(left, right) do
    Version.compare(left, right) == :eq
  end

  defp versions_equal_no_pre?(left, right) do
    versions_equal?(%{left | pre: []}, %{right | pre: []})
  end
end
