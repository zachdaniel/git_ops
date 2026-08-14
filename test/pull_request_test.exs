defmodule GitOps.Mix.Tasks.Test.PullRequestTest do
  use ExUnit.Case

  import GitOps.Test.MonorepoFixture

  alias Mix.Tasks.GitOps.Release
  alias Mix.Tasks.GitOps.TagMerged

  @config %{
    "repository_url" => "https://github.com/example/mono",
    "release_strategy" => "pull_request",
    "pr_labels" => ["autorelease: pending"],
    "packages" => %{
      "pkg_a" => %{
        "managed_files" => [%{"path" => "package.json", "type" => "json"}],
        "pr_group" => "main"
      },
      "pkg_b" => %{
        "managed_files" => [%{"path" => "version.txt", "type" => "raw"}],
        "pr_group" => "main"
      },
      "pkg_c" => %{
        "managed_files" => [%{"path" => "version.txt", "type" => "raw"}]
      }
    }
  }

  setup do
    dir =
      Path.join(
        System.tmp_dir!(),
        "git_ops_pr_test_#{System.unique_integer([:positive])}"
      )

    origin = Path.join(dir, "origin.git")
    work = Path.join(dir, "work")
    File.mkdir_p!(origin)

    isolate_in!(work)
    on_exit(fn -> File.rm_rf!(dir) end)
    Application.put_env(:git_ops, :repository_path, work)
    Application.put_env(:git_ops, :req_options, plug: {Req.Test, GitOps.GitHub})

    git!(origin, ["init", "-q", "--bare"])

    init_repo!(work)
    git!(work, ["remote", "add", "origin", origin])

    File.write!(Path.join(work, "git_ops.json"), Jason.encode!(@config))
    write!(work, "pkg_a/package.json", ~s({\n  "name": "a",\n  "version": "0.1.0"\n}\n))
    write!(work, "pkg_b/version.txt", "0.1.0\n")
    write!(work, "pkg_c/version.txt", "0.1.0\n")

    git!(work, ["add", "."])
    git!(work, ["commit", "-q", "-m", "chore: initial commit"])
    git!(work, ["tag", "pkg_a-v0.1.0"])
    git!(work, ["tag", "pkg_b-v0.1.0"])
    git!(work, ["tag", "pkg_c-v0.1.0"])
    git!(work, ["push", "-q", "origin", "main", "--tags"])

    %{work: work, origin: origin}
  end

  defp stub_github(test_pid) do
    Req.Test.stub(GitOps.GitHub, fn conn ->
      send(test_pid, {:github, conn.method, conn.request_path})

      case {conn.method, conn.request_path} do
        {"GET", "/repos/example/mono/pulls"} ->
          Req.Test.json(conn, [])

        {"POST", "/repos/example/mono/pulls"} ->
          conn
          |> Plug.Conn.put_status(201)
          |> Req.Test.json(%{
            "number" => 1,
            "html_url" => "https://github.com/example/mono/pull/1"
          })

        {"POST", "/repos/example/mono/issues/1/labels"} ->
          Req.Test.json(conn, [])

        {"POST", "/repos/example/mono/releases"} ->
          conn
          |> Plug.Conn.put_status(201)
          |> Req.Test.json(%{"html_url" => "https://github.com/example/mono/releases/tag/x"})
      end
    end)
  end

  test "pr_group members share a branch and PR; others get their own", %{
    work: work,
    origin: origin
  } do
    commit!(work, "pkg_a/lib.js", "code\n", "feat: a feature")
    commit!(work, "pkg_b/lib.txt", "text\n", "fix: b fix")
    commit!(work, "pkg_c/lib.txt", "text\n", "fix: c fix")
    stub_github(self())

    Release.run([])

    branches = git!(origin, ["branch", "--list"])
    assert branches =~ "git-ops/release/main"
    assert branches =~ "git-ops/release/pkg_c"

    package_json = git!(origin, ["show", "git-ops/release/main:pkg_a/package.json"])
    assert package_json =~ ~s("version": "0.2.0")

    assert git!(origin, ["show", "git-ops/release/main:pkg_b/version.txt"]) == "0.1.1\n"
    assert git!(origin, ["show", "git-ops/release/pkg_c:pkg_c/version.txt"]) == "0.1.1\n"

    changelog = git!(origin, ["show", "git-ops/release/main:pkg_a/CHANGELOG.md"])
    assert changelog =~ "## [0.2.0]"
    assert changelog =~ "a feature"

    assert_received {:github, "GET", "/repos/example/mono/pulls"}
    assert_received {:github, "POST", "/repos/example/mono/pulls"}
    assert_received {:github, "POST", "/repos/example/mono/issues/1/labels"}
    assert_received {:github, "GET", "/repos/example/mono/pulls"}
    assert_received {:github, "POST", "/repos/example/mono/pulls"}
    assert_received {:github, "POST", "/repos/example/mono/issues/1/labels"}

    # The working tree is untouched: proposals live only on the branches.
    assert File.read!(Path.join(work, "pkg_a/package.json")) =~ ~s("version": "0.1.0")
    refute File.exists?(Path.join(work, "pkg_a/CHANGELOG.md"))
  end

  test "a rerun with no new package commits pushes nothing and calls no APIs", %{
    work: work,
    origin: origin
  } do
    commit!(work, "pkg_a/lib.js", "code\n", "feat: a feature")
    stub_github(self())

    Release.run([])
    branch_sha = git!(origin, ["rev-parse", "refs/heads/git-ops/release/main"])

    # Drain the first run's API traffic so the rerun's silence is provable.
    flush_github_messages()

    # The branch's base moving must not count as a change.
    commit!(work, "README.md", "docs\n", "docs: outside every package")
    git!(work, ["push", "-q", "origin", "main"])

    Release.run([])

    assert git!(origin, ["rev-parse", "refs/heads/git-ops/release/main"]) == branch_sha
    refute_received {:github, _, _}
  end

  defp flush_github_messages do
    receive do
      {:github, _, _} -> flush_github_messages()
      {:github, _, _, _} -> flush_github_messages()
    after
      0 -> :ok
    end
  end

  test "closes the release pull request of a package with no releasable changes", %{work: work} do
    enable_closing_stale_pull_requests!(work)
    stub_stale_github(self())

    Release.run([])

    assert_received {:github, "POST", "/repos/example/mono/issues/7/comments"}
    assert_received {:github, "PATCH", "/repos/example/mono/pulls/7"}
  end

  test "a dry run reports the stale pull request instead of closing it", %{work: work} do
    enable_closing_stale_pull_requests!(work)
    stub_stale_github(self())

    Release.run(["--dry-run"])

    refute_received {:github, "POST", "/repos/example/mono/issues/7/comments"}
  end

  test "a package with releasable changes keeps its pull request open", %{work: work} do
    enable_closing_stale_pull_requests!(work)
    commit!(work, "pkg_c/lib.txt", "text\n", "fix: c fix")
    stub_stale_github(self())

    Release.run([])

    refute_received {:github, "POST", "/repos/example/mono/issues/7/comments"}
  end

  defp enable_closing_stale_pull_requests!(work) do
    File.write!(
      Path.join(work, "git_ops.json"),
      Jason.encode!(Map.put(@config, "close_stale_pull_requests", true))
    )

    GitOps.Config.reload_file_config()
  end

  # pkg_c has an open release pull request; the pr_group branch has none. The
  # comment POST is what distinguishes a close from an upsert, which PATCHes the
  # same pull request to refresh its title and body.
  defp stub_stale_github(test_pid) do
    Req.Test.stub(GitOps.GitHub, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      send(test_pid, {:github, conn.method, conn.request_path})

      case {conn.method, conn.request_path} do
        {"GET", "/repos/example/mono/pulls"} ->
          if conn.params["head"] == "example:git-ops/release/pkg_c" do
            Req.Test.json(conn, [%{"number" => 7}])
          else
            Req.Test.json(conn, [])
          end

        {"POST", "/repos/example/mono/pulls"} ->
          conn
          |> Plug.Conn.put_status(201)
          |> Req.Test.json(%{
            "number" => 7,
            "html_url" => "https://github.com/example/mono/pull/7"
          })

        {"POST", "/repos/example/mono/issues/7/comments"} ->
          Req.Test.json(conn, %{})

        {"POST", "/repos/example/mono/issues/7/labels"} ->
          Req.Test.json(conn, [])

        {"PATCH", "/repos/example/mono/pulls/7"} ->
          Req.Test.json(conn, %{"html_url" => "https://github.com/example/mono/pull/7"})
      end
    end)
  end

  defp enable_solo_pr!(work, extra \\ %{}) do
    config =
      @config
      |> put_in(["packages", "pkg_a", "solo_pr"], true)
      |> Map.merge(extra)

    File.write!(Path.join(work, "git_ops.json"), Jason.encode!(config))
    GitOps.Config.reload_file_config()
  end

  # Assigns a stable number per head branch and records every request body,
  # so the cross-linking PATCHes can be asserted on.
  defp stub_solo_github(test_pid) do
    numbers = %{"git-ops/release/main" => 10, "git-ops/release/pkg_a" => 11}

    Req.Test.stub(GitOps.GitHub, fn conn ->
      {:ok, raw_body, conn} = Plug.Conn.read_body(conn)
      payload = if raw_body == "", do: %{}, else: Jason.decode!(raw_body)
      send(test_pid, {:github, conn.method, conn.request_path, payload})

      case {conn.method, conn.request_path} do
        {"GET", "/repos/example/mono/pulls"} ->
          Req.Test.json(conn, [])

        {"POST", "/repos/example/mono/pulls"} ->
          number = Map.fetch!(numbers, payload["head"])

          conn
          |> Plug.Conn.put_status(201)
          |> Req.Test.json(%{
            "number" => number,
            "html_url" => "https://github.com/example/mono/pull/#{number}"
          })

        {"POST", "/repos/example/mono/issues/" <> _} ->
          Req.Test.json(conn, [])

        {"PATCH", "/repos/example/mono/pulls/" <> number} ->
          Req.Test.json(conn, %{
            "number" => String.to_integer(number),
            "html_url" => "https://github.com/example/mono/pull/#{number}"
          })
      end
    end)
  end

  test "maintains both the group PR and a standalone PR, cross-linked", %{
    work: work,
    origin: origin
  } do
    enable_solo_pr!(work)
    commit!(work, "pkg_a/lib.js", "code\n", "feat: a feature")
    commit!(work, "pkg_b/lib.txt", "text\n", "fix: b fix")
    stub_solo_github(self())

    Release.run([])

    branches = git!(origin, ["branch", "--list"])
    assert branches =~ "git-ops/release/main"
    assert branches =~ "git-ops/release/pkg_a"
    refute branches =~ "git-ops/release/pkg_b"

    # Both branches carry pkg_a's release; only the group branch carries pkg_b.
    assert git!(origin, ["show", "git-ops/release/main:pkg_a/package.json"]) =~
             ~s("version": "0.2.0")

    assert git!(origin, ["show", "git-ops/release/pkg_a:pkg_a/package.json"]) =~
             ~s("version": "0.2.0")

    assert git!(origin, ["show", "git-ops/release/main:pkg_b/version.txt"]) == "0.1.1\n"

    # The solo branch is cut from HEAD, so pkg_b's file is present but not bumped.
    assert git!(origin, ["show", "git-ops/release/pkg_a:pkg_b/version.txt"]) == "0.1.0\n"

    # Creation bodies carry the notices with search-by-branch fallback links.
    assert_received {:github, "POST", "/repos/example/mono/pulls",
                     %{"head" => "git-ops/release/main", "body" => group_body}}

    assert_received {:github, "POST", "/repos/example/mono/pulls",
                     %{"head" => "git-ops/release/pkg_a", "body" => solo_body}}

    assert group_body =~ "> [!NOTE]"
    assert group_body =~ "standalone release pull"
    assert group_body =~ "[`pkg_a`](https://github.com/example/mono/pulls?q="
    assert group_body =~ "**pkg_b**"

    assert solo_body =~ "> [!WARNING]"
    assert solo_body =~ "`main` group pull request"
    assert solo_body =~ "https://github.com/example/mono/pulls?q="
    refute solo_body =~ "**pkg_b**"

    # The second pass swaps the fallback links for direct PR links.
    assert_received {:github, "PATCH", "/repos/example/mono/pulls/10",
                     %{"body" => linked_group_body}}

    assert_received {:github, "PATCH", "/repos/example/mono/pulls/11",
                     %{"body" => linked_solo_body}}

    assert linked_group_body =~ "[`pkg_a`](https://github.com/example/mono/pull/11)"
    refute linked_group_body =~ "pulls?q="
    assert linked_solo_body =~ "(https://github.com/example/mono/pull/10)"
    refute linked_solo_body =~ "pulls?q="
  end

  test "a rerun with no new commits touches neither PR", %{work: work, origin: origin} do
    enable_solo_pr!(work)
    commit!(work, "pkg_a/lib.js", "code\n", "feat: a feature")
    stub_solo_github(self())

    Release.run([])
    main_sha = git!(origin, ["rev-parse", "refs/heads/git-ops/release/main"])
    solo_sha = git!(origin, ["rev-parse", "refs/heads/git-ops/release/pkg_a"])
    flush_github_messages()

    Release.run([])

    assert git!(origin, ["rev-parse", "refs/heads/git-ops/release/main"]) == main_sha
    assert git!(origin, ["rev-parse", "refs/heads/git-ops/release/pkg_a"]) == solo_sha
    refute_received {:github, _, _, _}
  end

  test "closes the standalone PR of a released package too", %{work: work} do
    enable_solo_pr!(work, %{"close_stale_pull_requests" => true})
    stub_stale_github(self())

    Release.run([])

    # pkg_a has no releasable changes: both its group's PR and its standalone
    # PR are looked up; only pkg_c's branch has one open (stubbed as #7).
    assert_received {:github, "POST", "/repos/example/mono/issues/7/comments"}
    assert_received {:github, "PATCH", "/repos/example/mono/pulls/7"}
  end

  test "--output writes both proposals, notices included", %{work: work} do
    enable_solo_pr!(work)
    commit!(work, "pkg_a/lib.js", "code\n", "feat: a feature")
    out = Path.join(work, "proposals")

    Release.run(["--dry-run", "--output", out])

    group_body = File.read!(Path.join(out, "main/PR_BODY.md"))
    solo_body = File.read!(Path.join(out, "pkg_a/PR_BODY.md"))

    assert group_body =~ "> [!NOTE]"
    assert solo_body =~ "> [!WARNING]"
    assert solo_body =~ "a feature"
    assert File.read!(Path.join(out, "pkg_a/pkg_a__package.json")) =~ ~s("version": "0.2.0")
  end

  test "a pr_group that cannot be a branch name is refused at parse time", %{work: work} do
    config = put_in(@config, ["packages", "pkg_a", "pr_group"], "my group")
    File.write!(Path.join(work, "git_ops.json"), Jason.encode!(config))
    GitOps.Config.reload_file_config()

    assert_raise RuntimeError, ~r/may only contain letters/, fn ->
      Release.run(["--dry-run"])
    end
  end

  test "dry run with --output writes proposals without pushing", %{
    work: work,
    origin: origin
  } do
    commit!(work, "pkg_a/lib.js", "code\n", "feat: a feature")
    out = Path.join(work, "proposals")

    Release.run(["--dry-run", "--output", out])

    refute git!(origin, ["branch", "--list"]) =~ "git-ops/release"

    body = File.read!(Path.join(out, "main/PR_BODY.md"))
    assert body =~ "**pkg_a**"
    assert body =~ "a feature"

    assert File.read!(Path.join(out, "main/pkg_a__package.json")) =~ ~s("version": "0.2.0")
    assert File.read!(Path.join(out, "main/pkg_a__CHANGELOG.md")) =~ "## [0.2.0]"
  end

  test "tag_merged tags merged releases and creates GitHub releases", %{
    work: work,
    origin: origin
  } do
    stub_github(self())

    # Simulate a merged release PR: version bump + changelog land on main.
    write!(work, "pkg_a/package.json", ~s({\n  "name": "a",\n  "version": "0.2.0"\n}\n))

    write!(
      work,
      "pkg_a/CHANGELOG.md",
      "# Change Log\n\n<!-- changelog -->\n\n## [0.2.0](link) (2026-08-10)\n\n### Features:\n\n* a feature\n"
    )

    git!(work, ["add", "."])
    git!(work, ["commit", "-q", "-m", "chore: release pkg_a 0.2.0"])
    git!(work, ["push", "-q", "origin", "main"])

    TagMerged.run([])

    assert git!(origin, ["tag", "--list"]) =~ "pkg_a-v0.2.0"
    assert_received {:github, "POST", "/repos/example/mono/releases"}

    tag_message = git!(work, ["tag", "-l", "-n100", "pkg_a-v0.2.0"])
    assert tag_message =~ "a feature"

    # Idempotent: a second run finds nothing to do.
    TagMerged.run([])
    refute_received {:github, "POST", "/repos/example/mono/releases"}
  end

  test "tag_merged refuses versions set outside a release commit", %{
    work: work,
    origin: origin
  } do
    write!(work, "pkg_a/package.json", ~s({\n  "name": "a",\n  "version": "0.2.0"\n}\n))
    git!(work, ["add", "."])
    git!(work, ["commit", "-q", "-m", "feat: sneaky version bump"])
    git!(work, ["push", "-q", "origin", "main"])

    TagMerged.run([])

    refute git!(origin, ["tag", "--list"]) =~ "pkg_a-v0.2.0"
  end

  test "tag_merged dry run tags nothing", %{work: work, origin: origin} do
    write!(work, "pkg_a/package.json", ~s({\n  "name": "a",\n  "version": "0.2.0"\n}\n))
    git!(work, ["add", "."])
    git!(work, ["commit", "-q", "-m", "chore: release pkg_a 0.2.0"])
    git!(work, ["push", "-q", "origin", "main"])

    TagMerged.run(["--dry-run"])

    refute git!(origin, ["tag", "--list"]) =~ "pkg_a-v0.2.0"
  end
end
