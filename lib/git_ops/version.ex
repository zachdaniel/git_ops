defmodule GitOps.Version do
  def first_valid_version(versions) do
    Enum.find(versions, fn version ->
      match?({:ok, _}, Version.parse(version))
    end)
  end

  def determine_new_version(old_version, commits) do
    parsed = Version.parse!(old_version)

    new_version =
      cond do
        Enum.any?(commits, &GitOps.Commit.breaking?/1) ->
          # major
          %{parsed | major: parsed.major + 1, minor: 0, patch: 0, pre: [], build: nil}

        Enum.any?(commits, &GitOps.Commit.feature?/1) ->
          %{parsed | minor: parsed.minor + 1, patch: 0, pre: [], build: nil}

        Enum.any?(commits, &GitOps.Commit.fix?/1) ->
          %{parsed | patch: parsed.patch + 1, pre: [], build: nil}

        true ->
          parsed
      end

    to_string(new_version)
  end
end
