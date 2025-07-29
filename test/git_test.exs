defmodule GitOps.Test.GitTest do
  use ExUnit.Case

  alias GitOps.Git

  describe "parse_git_log/1" do
    test "parses commits" do
      git_log_output = """
      075380d3dc81e80b37d02195184a784b0c0dd7a7--hash--chore: release version v2.8.0
      --message--Zach Daniel--author--zach@zachdaniel.dev--gitops--
      29f5b4ee1a9360902c43d5c2ce78c409e2c6e909--hash--chore: fix previous commit, store user_data
      --message--Zach Daniel--author--zach@zachdaniel.dev--gitops--
      91140d2393eb9d7462b4da4fa5439645ee0b8aa9--hash--chore: use `Req` and make references use usernames
      --message--Zach Daniel--author--zach@zachdaniel.dev--gitops--
      """

      result = Git.parse_git_log(git_log_output)

      assert length(result) == 3

      assert Enum.at(result, 0) == %{
               hash: "075380d3dc81e80b37d02195184a784b0c0dd7a7",
               message: "chore: release version v2.8.0",
               author_name: "Zach Daniel",
               author_email: "zach@zachdaniel.dev"
             }

      assert Enum.at(result, 1) == %{
               hash: "29f5b4ee1a9360902c43d5c2ce78c409e2c6e909",
               message: "chore: fix previous commit, store user_data",
               author_name: "Zach Daniel",
               author_email: "zach@zachdaniel.dev"
             }

      assert Enum.at(result, 2) == %{
               hash: "91140d2393eb9d7462b4da4fa5439645ee0b8aa9",
               message: "chore: use `Req` and make references use usernames",
               author_name: "Zach Daniel",
               author_email: "zach@zachdaniel.dev"
             }
    end

    test "handles empty git log output" do
      result = Git.parse_git_log("")
      assert result == []
    end

    test "handles git log output with only separators" do
      result = Git.parse_git_log("--gitops----gitops--")
      assert result == []
    end
  end
end
