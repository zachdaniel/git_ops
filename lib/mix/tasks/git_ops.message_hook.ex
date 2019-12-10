defmodule Mix.Tasks.GitOps.MsgHook do
  use Mix.Task

  @shortdoc "Enables automatic check if git commit message follows Conventional Commits spec"

  @commit_msg_hook_name "commit-msg"

  @moduledoc """
  Enables automatic check if git commit message follows Conventional Commits spec. It does that by
  installing `mix git_ops.check_message` as git #{@commit_msg_hook_name} hook.

      mix git_ops.msg_hook

  Logs an error if the git hook already exists.

  ## Switches:

  * `--force|-f` - Overwrite the git #{@commit_msg_hook_name} hook if it alerady exists.

  * `--uninstall` - Uninstalls the git #{@commit_msg_hook_name} hook if it exists.

  * `--verbose|-v` - Write more messages.
  """

  alias GitOps.Git

  @doc false
  def run(args) do
    {opts, _other_args, _} =
      OptionParser.parse(args,
        switches: [force: :boolean, uninstall: :boolean, verbose: :boolean],
        aliases: [f: :force, v: :verbose]
      )

    if opts[:uninstall] do
      uninstall(opts)
    else
      install(opts)
    end

    :ok
  end

  defp msg_hook_contains_template(commit_msg_hook_path, template_file_path, opts) do
    # regex to delete 1) lines starting with # and 2) empty lines
    normalize_regex = ~r/(*ANYCRLF)(^#.*\R)|(^\s*\R)/m

    normalized_template = Regex.replace(normalize_regex, File.read!(template_file_path), "")

    normalized_commit_msg_hook =
      Regex.replace(normalize_regex, File.read!(commit_msg_hook_path), "")

    if opts[:verbose] do
      Mix.shell().info("""
      Conventional Commits message validation script:
      #{normalized_template}

      Git #{@commit_msg_hook_name} hook script (normalized):
      #{normalized_commit_msg_hook}
      """)
    end

    {normalized_commit_msg_hook =~ normalized_template, normalized_template}
  end

  defp install(opts) do
    repo = Git.init!()

    commit_msg_hook_path =
      repo
      |> Git.hooks_path()
      |> Path.join(@commit_msg_hook_name)

    if opts[:verbose] do
      Mix.shell().info("""
      Git hooks path: #{commit_msg_hook_path}
      """)
    end

    commit_msg_hook_exists = File.exists?(commit_msg_hook_path)

    if opts[:verbose] do
      Mix.shell().info("""
      The Git #{@commit_msg_hook_name} hook #{
        if commit_msg_hook_exists, do: "exists", else: "does not exist"
      }
      """)
    end

    template_file_path =
      Path.join([:code.priv_dir(:git_ops), "githooks", "#{@commit_msg_hook_name}.template"])

    if commit_msg_hook_exists do
      case msg_hook_contains_template(commit_msg_hook_path, template_file_path, opts) do
        {true, _} ->
          if opts[:verbose] do
            Mix.shell().info("""
            Nothing to do: the #{@commit_msg_hook_name} hook `#{commit_msg_hook_path}` already contains the Conventional Commits message validation.
            """)
          end

        {false, normalized_template} ->
          if opts[:force] do
            Mix.shell().info("""
            The #{@commit_msg_hook_name} hook `#{commit_msg_hook_path}` does not contain the Conventional Commits message validation.
            """)

            if Mix.shell().yes?("Replacing forcefully (the current version will be lost)?") do
              Mix.shell().info("TODO: replacing")
            end
          else
            error_exit("""
            The #{@commit_msg_hook_name} hook `#{commit_msg_hook_path}` does not contain the Conventional Commits message validation.
            Please use --help to check the available options, or manually edit the hook to call the following:
            #{normalized_template}
            """)
          end
      end
    else
      install_commit_msg_hook!(template_file_path, commit_msg_hook_path, opts)
    end

    :ok
  end

  defp uninstall(_opts) do
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

  @spec error_exit(String.t()) :: no_return
  defp error_exit(message), do: raise(Mix.Error, message: message)
end
