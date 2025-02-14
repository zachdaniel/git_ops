# Suppress output of testing mix task
Mix.shell(Mix.Shell.Process)

defmodule GitOps.Mix.Tasks.Test.CheckMessageTest do
  use ExUnit.Case, async: false

  alias Mix.Tasks.GitOps.CheckMessage

  test "check message without parameters", _context do
    assert_raise Mix.Error, fn ->
      CheckMessage.run([])
    end
  end

  test "check message with invalid path", _context do
    assert_raise File.Error, fn ->
      CheckMessage.run(["path/to/nowhere"])
    end
  end

  describe "with --head" do
    setup do
      repo_path =
        System.tmp_dir!()
        |> Path.join("repo")

      repo = Git.init!(repo_path)

      Application.put_env(:git_ops, :repository_path, repo_path)

      on_exit(fn ->
        Application.delete_env(:git_ops, :repository_path)
        File.rm_rf!(repo_path)

        :ok
      end)

      {:ok, repo: repo}
    end

    test "it fails when the repo contains no commits" do
      assert_raise(Git.Error, ~r/does not have any commits/, fn ->
        CheckMessage.run(["--head"])
      end)
    end

    test "it fails when the latest commit does not have a valid message", %{repo: repo} do
      Git.commit!(repo, ["-m 'invalid message'", "--allow-empty"])

      assert_raise(Mix.Error, ~r/Not a valid Conventional Commit message/, fn ->
        CheckMessage.run(["--head"])
      end)
    end

    test "it succeeds when the latest commit has a valid message", %{repo: repo} do
      Git.commit!(repo, ["-m 'chore: counting toes'", "--allow-empty"])

      assert :ok = CheckMessage.run(["--head"])
    end
  end

  describe "with valid path" do
    setup do
      message_file_name = "test_commit_message"

      on_exit(fn -> delete_temp_file!(message_file_name) end)

      %{message_file_name: message_file_name}
    end

    test "check incorrect message", %{message_file_name: message_file_name} do
      temp_file_name =
        create_temp_file!(message_file_name, """
        fix division by zero
        """)

      assert_raise Mix.Error, ~r/Not a valid Conventional Commit message/, fn ->
        CheckMessage.run([temp_file_name])
      end
    end

    test "mix task return code for incorrect message", %{message_file_name: message_file_name} do
      temp_file_name =
        create_temp_file!(message_file_name, """
        invalid message
        """)

      {_output, exit_status} =
        System.cmd("mix", ["git_ops.check_message", temp_file_name], stderr_to_stdout: true)

      assert exit_status > 0
    end

    test "check correct message", %{message_file_name: message_file_name} do
      temp_file_name =
        create_temp_file!(message_file_name, """
        fix: division by zero
        """)

      assert :ok == CheckMessage.run([temp_file_name])
    end
  end

  defp temp_file_name(name), do: Path.join(System.tmp_dir!(), name)

  defp delete_temp_file!(name) do
    tmp_file = temp_file_name(name)
    File.rm!(tmp_file)
  end

  defp create_temp_file!(name, content) do
    tmp_file = temp_file_name(name)
    File.write!(tmp_file, content)
    tmp_file
  end
end
