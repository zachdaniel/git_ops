defmodule GitOps.Test.MonorepoFixture do
  @moduledoc false

  import ExUnit.Callbacks, only: [on_exit: 1]

  @doc """
  Clears the :git_ops application environment, points it at `dir`, and makes
  `dir` the working directory — restoring and deleting everything on exit.
  """
  def isolate_in!(dir) do
    File.mkdir_p!(dir)
    original_cwd = File.cwd!()
    original_env = Application.get_all_env(:git_ops)

    Enum.each(original_env, fn {key, _} -> Application.delete_env(:git_ops, key) end)
    Application.put_env(:git_ops, :repository_path, dir)
    File.cd!(dir)
    GitOps.Config.reload_file_config()

    on_exit(fn ->
      File.cd!(original_cwd)

      Enum.each(Application.get_all_env(:git_ops), fn {key, _} ->
        Application.delete_env(:git_ops, key)
      end)

      Enum.each(original_env, fn {key, value} -> Application.put_env(:git_ops, key, value) end)
      File.rm_rf!(dir)
    end)
  end

  def init_repo!(dir) do
    git!(dir, ["init", "-q", "-b", "main"])
    git!(dir, ["config", "user.email", "test@example.com"])
    git!(dir, ["config", "user.name", "Test"])
    git!(dir, ["config", "commit.gpgsign", "false"])
    git!(dir, ["config", "tag.gpgsign", "false"])
  end

  def git!(dir, args) do
    {output, 0} = System.cmd("git", args, cd: dir, stderr_to_stdout: true)
    output
  end

  def write!(dir, path, contents) do
    full = Path.join(dir, path)
    File.mkdir_p!(Path.dirname(full))
    File.write!(full, contents)
  end

  def commit!(dir, path, contents, message) do
    write!(dir, path, contents)
    git!(dir, ["add", "."])
    git!(dir, ["commit", "-q", "-m", message])
  end
end
