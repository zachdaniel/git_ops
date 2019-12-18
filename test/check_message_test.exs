defmodule GitOps.Mix.Tasks.Test.CheckMessageTest do
  use ExUnit.Case

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
