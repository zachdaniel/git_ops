defmodule GitOps.Version do
  @moduledoc """
  Functionality around parsing and comparing versions contained in git tags
  """

  alias GitOps.Commit

  @spec last_valid_non_rc_version([String.t()], String.t()) :: String.t() | nil
  def last_valid_non_rc_version(versions, prefix) do
    versions
    |> Enum.reverse()
    |> Enum.find(fn version ->
      match?({:ok, %{pre: []}}, parse(prefix, version))
    end)
  end

  def determine_new_version(current_version, prefix, commits, opts) do
    parsed = parse!(prefix, prefix <> current_version)

    rc? = opts[:rc]

    build = opts[:build]

    new_version = new_version(commits, parsed, rc?, opts)

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
      |> Map.put(:build, build)
      |> to_string()

    prefix <> unprefixed
  end

  def last_version_greater_than(versions, last_version, prefix) do
    Enum.find(versions, fn version ->
      case parse(prefix, version) do
        {:ok, version} ->
          Version.compare(version, parse!(prefix, last_version)) == :gt

        _ ->
          false
      end
    end)
  end

  defp new_version(commits, parsed, rc?, opts) do
    pre = default_pre_release(rc?, opts[:pre_release])

    cond do
      Enum.any?(commits, &Commit.breaking?/1) ->
        if opts[:no_major] do
          %{parsed | minor: parsed.minor + 1, patch: 0, pre: pre}
        else
          %{parsed | major: parsed.major + 1, minor: 0, patch: 0, pre: pre}
        end

      Enum.any?(commits, &Commit.feature?/1) ->
        %{parsed | minor: parsed.minor + 1, patch: 0, pre: pre}

      Enum.any?(commits, &Commit.fix?/1) || opts[:force_patch] ->
        new_version_patch(parsed, pre, rc?)

      true ->
        parsed
    end
  end

  defp default_pre_release(true, _pre_release), do: ["rc0"]
  defp default_pre_release(_rc?, pre_release), do: List.wrap(pre_release)

  defp new_version_patch(parsed, pre, rc?) do
    case {parsed, pre, rc?} do
      {parsed, [], _} -> %{parsed | patch: parsed.patch + 1, pre: []}
      {parsed = %{pre: []}, pre, _} -> %{parsed | patch: parsed.patch + 1, pre: pre}
      {parsed, _, true} -> %{parsed | pre: increment_rc!(parsed.pre)}
      {parsed = %{pre: ["rc" <> _]}, pre, nil} -> %{parsed | patch: parsed.patch + 1, pre: pre}
      {parsed, pre, _} -> %{parsed | pre: pre}
    end
  end

  defp increment_rc!(nil), do: "rc0"
  defp increment_rc!([]), do: ["rc0"]
  defp increment_rc!([rc]), do: List.wrap(increment_rc!(rc))

  defp increment_rc!(rc = "rc" <> version) do
    case Integer.parse(version) do
      {int, ""} ->
        "rc#{int + 1}"

      :error ->
        raise "Found an rc version that could not be parsed: #{rc}"
    end
  end

  defp increment_rc!(rc) do
    raise "Found an rc version that could not be parsed: #{rc}"
  end

  defp versions_equal?(left, right) do
    Version.compare(left, right) == :eq
  end

  defp parse(_, version = %Version{}), do: {:ok, version}
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
