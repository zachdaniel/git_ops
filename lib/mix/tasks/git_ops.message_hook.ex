defmodule Mix.Tasks.GitOps.MessageHook do
  use Mix.Task

  @shortdoc "Enables automatic check if git commit message follows Conventional Commits spec"

  @commit_msg_hook_name "commit-msg"

  @moduledoc """
  Installs a Git #{@commit_msg_hook_name} hook to automatically check if the commit message follows
  the Conventional Commits spec:

      mix git_ops.message_hook

  The actual check is done by using the git_ops.check_message mix task:

      mix git_ops.check_message /path/to/commit/message/file

  It does nothing if a Git #{@commit_msg_hook_name} hook already exists that contains the above
  message validation task (unless --force was used).

  Logs an error if a Git #{@commit_msg_hook_name} hook exists but it does not call the message
  validation task.

  ## Switches:

  * `--force|-f` - Overwrites the Git #{@commit_msg_hook_name} hook if one exists but it does not
    call the message validation task.

  * `--uninstall` - Uninstalls the git #{@commit_msg_hook_name} hook if it exists.

  * `--verbose|-v` - Be more verbose. Pass this option twice to be even more verbose.
  """

  alias GitOps.Git

  @doc false
  def run(args) do
    {opts, _other_args, _} =
      OptionParser.parse(args,
        strict: [
          force: :boolean,
          uninstall: :boolean,
          verbose: :count,
          commit_msg_hook_path_override: :string
        ],
        aliases: [f: :force, v: :verbose]
      )

    opts = Keyword.merge([verbose: 0], opts)

    if opts[:uninstall] do
      uninstall(opts)
    else
      install(opts)
    end

    :ok
  end

  defp install(opts) do
    {commit_msg_hook_path, commit_msg_hook_exists} = commit_msg_hook_info!(opts)

    template_file_path = template_file_path(opts)

    if commit_msg_hook_exists do
      normalized_commit_msg_hook =
        normalize_script!(
          commit_msg_hook_path,
          "Git #{@commit_msg_hook_name} hook script (normalized)",
          opts
        )

      normalized_validation_script =
        normalize_script!(
          template_file_path,
          "Conventional Commits message validation script",
          opts
        )

      if normalized_commit_msg_hook =~ normalized_validation_script do
        if opts[:verbose] >= 1 do
          Mix.shell().info("""
          Nothing to do: the #{@commit_msg_hook_name} hook `#{commit_msg_hook_path}` already contains the Conventional Commits message validation.
          """)
        end
      else
        if opts[:force] do
          Mix.shell().info("""
          The #{@commit_msg_hook_name} hook `#{commit_msg_hook_path}` does not call the Conventional Commits message validation task.
          """)

          if Mix.shell().yes?("Replacing forcefully (the current version will be lost)?") do
            install_commit_msg_hook!(template_file_path, commit_msg_hook_path, opts)
          end
        else
          error_exit("""
          The #{@commit_msg_hook_name} hook `#{commit_msg_hook_path}` does not call the Conventional Commits message validation task.
          Please use --help to check the available options, or manually edit the hook to call the following:
          #{normalized_validation_script}
          """)
        end
      end
    else
      install_commit_msg_hook!(template_file_path, commit_msg_hook_path, opts)
    end

    :ok
  end

  defp uninstall(opts) do
    {commit_msg_hook_path, commit_msg_hook_exists} = commit_msg_hook_info!(opts)

    template_file_path = template_file_path(opts)

    if commit_msg_hook_exists do
      normalized_commit_msg_hook =
        normalize_script!(
          commit_msg_hook_path,
          "Git #{@commit_msg_hook_name} hook script (normalized)",
          opts
        )

      normalized_validation_script =
        normalize_script!(
          template_file_path,
          "Conventional Commits message validation script",
          opts
        )

      if normalized_commit_msg_hook == normalized_validation_script do
        uninstall_commit_msg_hook!(commit_msg_hook_path, opts)
      else
        error_exit("""
        The #{@commit_msg_hook_name} hook `#{commit_msg_hook_path}` will not be deleted because it
        is not identical to the version installed by this tool. Please check it manually.
        """)
      end
    else
      error_exit("""
      The #{@commit_msg_hook_name} hook `#{commit_msg_hook_path}` does not exists. Nothing to uninstall.
      """)
    end

    :ok
  end

  defp install_commit_msg_hook!(template_file_path, commit_msg_hook_path, _opts) do
    Mix.shell().info("""
    Installing #{@commit_msg_hook_name} hook from #{template_file_path} to #{commit_msg_hook_path}...
    """)

    File.cp!(template_file_path, commit_msg_hook_path)

    Mix.shell().info("""
    done.
    """)
  end

  defp uninstall_commit_msg_hook!(commit_msg_hook_path, _opts) do
    Mix.shell().info("""
    Uninstalling #{@commit_msg_hook_name} hook from #{commit_msg_hook_path}...
    """)

    File.rm!(commit_msg_hook_path)

    Mix.shell().info("""
    done.
    """)
  end

  defp commit_msg_hook_info!(opts) do
    commit_msg_hook_path_override = opts[:commit_msg_hook_path_override]

    commit_msg_hook_path =
      if commit_msg_hook_path_override && is_binary(commit_msg_hook_path_override) do
        commit_msg_hook_path_override
      else
        Git.init!()
        |> Git.hooks_path()
        |> Path.join(@commit_msg_hook_name)
      end

    commit_msg_hook_exists = File.exists?(commit_msg_hook_path)

    if opts[:verbose] >= 2 do
      Mix.shell().info("""
      Git hooks path: #{commit_msg_hook_path} (#{
        if commit_msg_hook_exists, do: "existing", else: "not existing"
      })
      """)
    end

    {commit_msg_hook_path, commit_msg_hook_exists}
  end

  defp template_file_path(_opts) do
    Path.join([:code.priv_dir(:git_ops), "githooks", "#{@commit_msg_hook_name}.template"])
  end

  defp normalize_script!(script_path, desciption, opts) do
    # regex to delete 1) lines starting with # and 2) empty lines
    normalize_regex = ~r/(*ANYCRLF)(^#.*\R)|(^\s*\R)/m

    normalized_script = Regex.replace(normalize_regex, File.read!(script_path), "")

    if opts[:verbose] >= 2 do
      Mix.shell().info("""
      #{desciption}:
      #{normalized_script}
      """)
    end

    normalized_script
  end

  @spec error_exit(String.t()) :: no_return
  defp error_exit(message), do: raise(Mix.Error, message: message)
end
