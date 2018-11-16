defmodule GitOps.Version do
  @moduledoc """
  Functionality around parsing and comparing versions contained in git tags
  """

  @dialyzer {:nowarn_function,
             parse!: 2,
             versions_equal_no_pre?: 2,
             versions_equal?: 2,
             do_increment_rc!: 1,
             increment_rc!: 2,
             determine_new_version: 4,
             last_valid_non_rc_version: 2,
             last_pre_release_version_after: 3,
             new_version: 3}

  @spec last_valid_non_rc_version([String.t()], String.t()) :: String.t() | nil
  def last_valid_non_rc_version(versions, prefix) do
    versions
    |> Enum.reverse()
    |> Enum.find(fn version ->
      match?({:ok, %{pre: []}}, parse(prefix, version))
    end)
  end

  def determine_new_version(versions, prefix, commits, opts) do
    last_non_rc = last_valid_non_rc_version(versions, prefix)

    parsed = parse!(prefix, last_non_rc)

    rc? = opts[:rc]

    build = opts[:build]

    new_version = new_version(commits, parsed, opts)

    pre_release =
      if rc? do
        versions
        |> last_pre_release_version_after(parsed, prefix)
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

    unprefixed =
      new_version
      |> Map.put(:pre, pre_release)
      |> Map.put(:build, build)
      |> to_string()

    prefix <> unprefixed
  end

  def last_pre_release_version_after(versions, last_version, prefix) do
    last_version_without_prefix = String.trim_leading(last_version, prefix)

    Enum.find(versions, fn version ->
      case parse(prefix, version) do
        {:ok, version} ->
          Version.compare(version, last_version_without_prefix) == :gt

        _ ->
          false
      end
    end)
  end

  defp new_version(commits, parsed, opts) do
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
  end

  defp increment_rc!(nil, _), do: "rc0"

  defp increment_rc!(last_pre_release_version, new_version) do
    parsed_pre_release = parse!("", last_pre_release_version)

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

  defp parse("", text), do: Version.parse(text)

  defp parse(prefix, text) do
    if String.starts_with?(text, prefix) do
      text
      |> String.trim_leading(prefix)
      |> Version.parse()
    else
      :error
    end
  end

  defp parse!(prefix, text) do
    case parse(prefix, text) do
      {:ok, parsed} ->
        parsed

      :error ->
        raise ArgumentError, "Expected: #{text} to be parseable as a version, but it was not."
    end
  end
end
