defmodule GitOps.VersionReplace do
  @moduledoc """
  Functions that handle the logic behind replacing the version in related files.
  """

  @spec update_mix_project(module, String.t(), String.t()) :: :ok | {:error, :bad_replace}
  def update_mix_project(mix_project, current_version, new_version) do
    file = mix_project.module_info()[:compile][:source]

    update_file(file, "@version \"#{current_version}\"", "@version \"#{new_version}\"")
  end

  @spec update_readme(String.t(), String.t(), String.t()) :: :ok | {:error, :bad_replace}
  def update_readme(readme, current_version, new_version) do
    update_file(readme, ", \"~> #{current_version}\"", ", \"~> #{new_version}\"")
  end

  defp update_file(file, replace, pattern) do
    contents = File.read!(file)

    new_contents =
      String.replace(contents, replace, pattern)

    if new_contents == contents do
      {:error, :bad_replace}
    else
      File.write!(file, new_contents)

      :ok
    end
  end
end
