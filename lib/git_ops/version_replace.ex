defmodule GitOps.VersionReplace do
  @moduledoc """
  Functions that handle the logic behind replacing the version in related files.
  """

  @spec update_managed_file(
          {String.t(), (String.t() -> String.t()), (String.t() -> String.t())},
          String.t(),
          String.t(),
          keyword()
        ) :: String.t() | {:error, :bad_replace}
  def update_managed_file(managed_file = {file, _, _}, current_version, new_version, opts \\ []) do
    contents = File.read!(file)

    case render(managed_file, contents, current_version, new_version) do
      {:error, :bad_replace} ->
        {:error, :bad_replace}

      {:ok, new_contents} ->
        if !opts[:dry_run] do
          File.write!(file, new_contents)
        end

        String.trim(new_contents, contents)
    end
  end

  @doc """
  The updated contents of a managed file, without touching the filesystem.
  """
  @spec render(
          {String.t(), (String.t() -> String.t()), (String.t() -> String.t())},
          String.t(),
          String.t(),
          String.t()
        ) :: {:ok, String.t()} | {:error, :bad_replace}
  def render({_file, replace, pattern}, contents, current_version, new_version)
      when is_function(replace, 1) and is_function(pattern, 1) do
    new_contents = String.replace(contents, replace.(current_version), pattern.(new_version))

    if new_contents == contents do
      {:error, :bad_replace}
    else
      {:ok, new_contents}
    end
  end
end
