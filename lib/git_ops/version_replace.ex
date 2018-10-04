defmodule GitOps.VersionReplace do
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

  def update_readme(readme, current_version, new_version) do
    contents = File.read!(readme)

    new_contents =
      String.replace(contents, ", \"~> #{current_version}\"", ", \"~> #{new_version}\"")

    if new_contents == contents do
      {:error, :bad_replace}
    else
      File.write!(readme, new_contents)
    end
  end
end
