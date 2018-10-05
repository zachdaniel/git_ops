defmodule GitOps.VersionReplace do
  @moduledoc """
  Functions that handle the logic behind replacing the version in related files.
  """

  @spec update_mix_project(module, String.t(), String.t()) :: :ok | {:error, :bad_replace}
  def update_mix_project(mix_project, current_version, new_version) do
    file = mix_project.module_info()[:compile][:source]

    contents = File.read!(file)

    new_contents =
      String.replace(contents, "@version \"#{current_version}\"", "@version \"#{new_version}\"")

    if new_contents == contents do
      {:error, :bad_replace}
    else
      File.write!(file, new_contents)

      :ok
    end
  end

  @spec update_readme(String.t(), String.t(), String.t()) :: :ok | {:error, :bad_replace}
  def update_readme(readme, current_version, new_version) do
    contents = File.read!(readme)

    new_contents =
      String.replace(contents, ", \"~> #{current_version}\"", ", \"~> #{new_version}\"")

    if new_contents == contents do
      {:error, :bad_replace}
    else
      File.write!(readme, new_contents)

      :ok
    end
  end
end
