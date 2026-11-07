defmodule GitOps.Test.GitTest do
  use ExUnit.Case

  alias GitOps.Git

  describe "parse_git_log/1" do
    defp log_entry(hash, message, name, email), do: "#{hash}\0#{message}\0#{name}\0#{email}\0"

    test "parses commits" do
      git_log_output =
        log_entry(
          "075380d3dc81e80b37d02195184a784b0c0dd7a7",
          "chore: release version v2.8.0",
          "Zach Daniel",
          "zach@zachdaniel.dev"
        ) <>
          log_entry(
            "29f5b4ee1a9360902c43d5c2ce78c409e2c6e909",
            "chore: fix previous commit, store user_data",
            "Zach Daniel",
            "zach@zachdaniel.dev"
          ) <>
          log_entry(
            "91140d2393eb9d7462b4da4fa5439645ee0b8aa9",
            "chore: use `Req` and make references use usernames",
            "Zach Daniel",
            "zach@zachdaniel.dev"
          )

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

    test "a commit body containing delimiter text cannot forge or drop records" do
      repo_path =
        Path.join(System.tmp_dir!(), "git_ops_3247_#{System.unique_integer([:positive])}")

      File.mkdir_p!(repo_path)

      git = fn args ->
        {out, 0} = System.cmd("git", args, cd: repo_path, stderr_to_stdout: true)
        String.trim(out)
      end

      git.(["init", "--quiet"])
      git.(["config", "user.name", "Outside Attacker"])
      git.(["config", "user.email", "attacker@example.invalid"])
      File.write!(Path.join(repo_path, "change.txt"), "harmless change")
      git.(["add", "change.txt"])

      injected_body =
        "\n--gitops--\ndeadbeef--hash--feat!: forged major release--message--" <>
          "Trusted Maintainer--author--maintainer@example.com\n--gitops--\n"

      git.(["commit", "--quiet", "-m", "fix: harmless change", "-m", injected_body])
      actual_hash = git.(["rev-parse", "HEAD"])

      records = Git.get_commit_info(Git.init!(repo_path), :all)
      File.rm_rf!(repo_path)

      assert length(records) == 1
      assert hd(records).hash == actual_hash
      refute Enum.any?(records, &(&1.hash == "deadbeef"))
      assert hd(records).author_email == "attacker@example.invalid"
    end
  end

  describe "tags/1" do
    setup do
      repo_path =
        Path.join(System.tmp_dir!(), "git_ops_tags_#{System.unique_integer([:positive])}")

      File.mkdir_p!(repo_path)
      on_exit(fn -> File.rm_rf!(repo_path) end)

      git = fn args, env ->
        {out, 0} = System.cmd("git", args, cd: repo_path, env: env, stderr_to_stdout: true)
        String.trim(out)
      end

      commit = fn message, date ->
        File.write!(Path.join(repo_path, "file.txt"), message)
        git.(["add", "file.txt"], [])

        git.(["commit", "--quiet", "-m", message], [
          {"GIT_AUTHOR_DATE", date},
          {"GIT_COMMITTER_DATE", date}
        ])
      end

      git.(["init", "--quiet", "--initial-branch", "main"], [])
      git.(["config", "user.name", "Test"], [])
      git.(["config", "user.email", "test@example.com"], [])
      git.(["config", "tag.gpgSign", "false"], [])

      # main:  v1.0.0 ── v2.0.0-rc.0 ── (HEAD)
      #          └── 1.x: v1.0.1, committed after v2.0.0-rc.0
      commit.("chore: release version v1.0.0", "2026-01-01T00:00:00Z")
      git.(["tag", "v1.0.0"], [])
      git.(["branch", "1.x"], [])
      commit.("chore: release version v2.0.0-rc.0", "2026-02-01T00:00:00Z")
      git.(["tag", "-a", "v2.0.0-rc.0", "-m", "v2.0.0-rc.0"], [])
      git.(["switch", "--quiet", "1.x"], [])
      commit.("chore: release version v1.0.1", "2026-03-01T00:00:00Z")
      git.(["tag", "v1.0.1"], [])
      git.(["switch", "--quiet", "main"], [])
      commit.("fix: something on main", "2026-04-01T00:00:00Z")

      %{repo: Git.init!(repo_path), git: git}
    end

    test "ignores newer tags that are not reachable from HEAD", %{repo: repo} do
      tags = Git.tags(repo)

      refute "v1.0.1" in tags
      assert GitOps.Version.last_valid_version(tags, "v") == "v2.0.0-rc.0"
      assert GitOps.Version.last_valid_non_rc_version(tags, "v") == "v1.0.0"
    end

    test "uses the current branch's tags on a maintenance branch", %{repo: repo, git: git} do
      git.(["switch", "--quiet", "1.x"], [])
      tags = Git.tags(repo)

      refute "v2.0.0-rc.0" in tags
      assert GitOps.Version.last_valid_version(tags, "v") == "v1.0.1"
    end
  end

  describe "tag_exists?/2" do
    setup do
      repo = Git.init!(".")
      %{repo: repo}
    end

    test "returns true for a tag that exists locally", %{repo: repo} do
      assert Git.tag_exists?(repo, "0.1.0")
    end

    test "returns false for a tag that does not exist locally", %{repo: repo} do
      refute Git.tag_exists?(repo, "v999.999.999-nonexistent")
    end
  end
end
