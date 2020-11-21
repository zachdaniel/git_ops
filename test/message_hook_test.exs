# Read Mix input from current process to test user input
Mix.shell(Mix.Shell.Process)

defmodule GitOps.Mix.Tasks.Test.MessageHookTest do
  use ExUnit.Case

  alias Mix.Tasks.GitOps.MessageHook

  setup do
    test_hooks_dir = "test_hooks_dir"

    on_exit(fn -> delete_temp_dir!(test_hooks_dir) end)

    %{test_hooks_dir: test_hooks_dir}
  end

  test "install hook when missing", %{test_hooks_dir: test_hooks_dir} do
    hooks_dir = create_temp_dir!(test_hooks_dir)
    commit_msg_hook_path = Path.join(hooks_dir, "commit-msg")

    refute File.exists?(commit_msg_hook_path)
    assert :ok == MessageHook.run(["--commit-msg-hook-path-override", commit_msg_hook_path])
    assert File.exists?(commit_msg_hook_path)
    assert File.read!(commit_msg_hook_path) =~ ~S{mix git_ops.check_message "$@"}
  end

  test "install hook when already installed", %{test_hooks_dir: test_hooks_dir} do
    hooks_dir = create_temp_dir!(test_hooks_dir)
    commit_msg_hook_path = Path.join(hooks_dir, "commit-msg")

    MessageHook.run(["--commit-msg-hook-path-override", commit_msg_hook_path])
    content = File.read!(commit_msg_hook_path)

    assert :ok == MessageHook.run(["--commit-msg-hook-path-override", commit_msg_hook_path])
    assert content == File.read!(commit_msg_hook_path)
  end

  test "install hook when existing and different", %{test_hooks_dir: test_hooks_dir} do
    hooks_dir = create_temp_dir!(test_hooks_dir)
    commit_msg_hook_path = Path.join(hooks_dir, "commit-msg")
    initial_content = "initial content"

    File.write!(commit_msg_hook_path, initial_content)

    assert File.exists?(commit_msg_hook_path)
    refute File.read!(commit_msg_hook_path) =~ ~S{mix git_ops.check_message "$@"}

    regex =
      ~r/The commit-msg hook `.*` does not call the Conventional Commits message validation task/

    assert_raise Mix.Error, regex, fn ->
      MessageHook.run(["--commit-msg-hook-path-override", commit_msg_hook_path])
    end

    assert File.exists?(commit_msg_hook_path)
    assert initial_content == File.read!(commit_msg_hook_path)
  end

  test "install hook when existing and different - force mode", %{
    test_hooks_dir: test_hooks_dir
  } do
    send(self(), {:mix_shell_input, :yes?, true})

    hooks_dir = create_temp_dir!(test_hooks_dir)
    commit_msg_hook_path = Path.join(hooks_dir, "commit-msg")

    File.write!(commit_msg_hook_path, "initial script")

    assert File.exists?(commit_msg_hook_path)
    refute File.read!(commit_msg_hook_path) =~ ~S{mix git_ops.check_message "$@"}

    assert :ok ==
             MessageHook.run([
               "--commit-msg-hook-path-override",
               commit_msg_hook_path,
               "--force"
             ])

    assert File.exists?(commit_msg_hook_path)
    assert File.read!(commit_msg_hook_path) =~ ~S{mix git_ops.check_message "$@"}
  end

  test "install hook when existing and different - force mode - user rejects prompt", %{
    test_hooks_dir: test_hooks_dir
  } do
    send(self(), {:mix_shell_input, :yes?, false})

    hooks_dir = create_temp_dir!(test_hooks_dir)
    commit_msg_hook_path = Path.join(hooks_dir, "commit-msg")
    initial_content = "initial content"

    File.write!(commit_msg_hook_path, initial_content)

    assert File.exists?(commit_msg_hook_path)
    refute File.read!(commit_msg_hook_path) =~ ~S{mix git_ops.check_message "$@"}

    assert :ok ==
             MessageHook.run([
               "--commit-msg-hook-path-override",
               commit_msg_hook_path,
               "--force"
             ])

    assert File.exists?(commit_msg_hook_path)
    assert initial_content == File.read!(commit_msg_hook_path)
  end

  test "uninstall hook", %{test_hooks_dir: test_hooks_dir} do
    hooks_dir = create_temp_dir!(test_hooks_dir)
    commit_msg_hook_path = Path.join(hooks_dir, "commit-msg")

    MessageHook.run(["--commit-msg-hook-path-override", commit_msg_hook_path])

    assert :ok ==
             MessageHook.run([
               "--commit-msg-hook-path-override",
               commit_msg_hook_path,
               "--uninstall"
             ])

    refute File.exists?(commit_msg_hook_path)
  end

  test "uninstall hook - nonexisting", %{test_hooks_dir: test_hooks_dir} do
    hooks_dir = create_temp_dir!(test_hooks_dir)
    commit_msg_hook_path = Path.join(hooks_dir, "commit-msg")

    refute File.exists?(commit_msg_hook_path)

    assert_raise Mix.Error,
                 ~r{The commit-msg hook `.*` does not exists. Nothing to uninstall.},
                 fn ->
                   MessageHook.run([
                     "--commit-msg-hook-path-override",
                     commit_msg_hook_path,
                     "--uninstall"
                   ])
                 end
  end

  test "uninstall hook - different", %{test_hooks_dir: test_hooks_dir} do
    hooks_dir = create_temp_dir!(test_hooks_dir)
    commit_msg_hook_path = Path.join(hooks_dir, "commit-msg")
    initial_content = "initial content"

    File.write!(commit_msg_hook_path, initial_content)

    assert File.exists?(commit_msg_hook_path)
    refute File.read!(commit_msg_hook_path) =~ ~S{mix git_ops.check_message "$@"}

    assert_raise Mix.Error,
                 ~r{The commit-msg hook `.*` will not be deleted},
                 fn ->
                   MessageHook.run([
                     "--commit-msg-hook-path-override",
                     commit_msg_hook_path,
                     "--uninstall"
                   ])
                 end

    assert initial_content == File.read!(commit_msg_hook_path)
  end

  defp temp_dir_name(name), do: Path.join(System.tmp_dir!(), name)

  defp delete_temp_dir!(name) do
    dir_name = temp_dir_name(name)
    File.rm_rf!(dir_name)
  end

  defp create_temp_dir!(name) do
    dir_name = temp_dir_name(name)
    File.mkdir!(dir_name)
    dir_name
  end
end
