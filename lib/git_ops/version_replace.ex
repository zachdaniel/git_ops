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
  def update_managed_file({file, replace, pattern}, current_version, new_version, opts \\ [])
      when is_function(replace, 1) and is_function(pattern, 1) do
    contents = File.read!(file)
    new_contents = String.replace(contents, replace.(current_version), pattern.(new_version))

    if new_contents == contents do
      {:error, :bad_replace}
    else
      if !opts[:dry_run] do
        File.write!(file, new_contents)
      end

      String.trim(new_contents, contents)
    end
  end
end
