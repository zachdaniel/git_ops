defmodule GitOps.VersionReplace do
  @moduledoc """
  Functions that handle the logic behind replacing the version in related files.
  """

  @spec update_mix_project(module, String.t(), String.t()) :: String.t() | {:error, :bad_replace}
  def update_mix_project(mix_project, current_version, new_version, opts \\ []) do
    file = mix_project.module_info()[:compile][:source]

    update_file(file, "@version \"#{current_version}\"", "@version \"#{new_version}\"", opts)
  end

  @spec update_readme(
          String.t()
          | {String.t(), fun :: (String.t() -> String.t()), fun :: (String.t() -> String.t())},
          String.t(),
          String.t()
        ) :: String.t() | {:error, :bad_replace}
  def update_readme(readme, current_version, new_version, opts \\ [])

  def update_readme({readme, replace, pattern}, current_version, new_version, opts)
      when is_function(replace, 1) and is_function(pattern, 1) do
    update_file(readme, replace.(current_version), pattern.(new_version), opts)
  end

  def update_readme(readme, current_version, new_version, opts) do
    update_file(readme, ", \"~> #{current_version}\"", ", \"~> #{new_version}\"", opts)
  end

  defp update_file(file, replace, pattern, opts) do
    contents = File.read!(file)

    new_contents = String.replace(contents, replace, pattern)

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
