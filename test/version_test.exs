defmodule GitOps.Test.VersionTest do
  use ExUnit.Case

  alias GitOps.Version

  defp new_version(current_version, commits, opts \\ []) do
    {prefix, opts} = Keyword.pop(opts, :prefix)

    Version.determine_new_version(current_version, prefix || "", commits, opts)
  end

  defp minor do
    %GitOps.Commit{
      type: "feat",
      message: "feat"
    }
  end

  defp patch do
    %GitOps.Commit{
      type: "fix",
      message: "fix"
    }
  end

  defp chore do
    %GitOps.Commit{
      type: "chore",
      message: "chore"
    }
  end

  defp break do
    %{minor() | breaking?: true}
  end

  test "a new version containing a patch commit increments only the patch" do
    assert new_version("0.1.0", [patch()]) == "0.1.1"
  end

  test "a new version containing a minor commit increments the minor" do
    assert new_version("0.1.0", [minor()]) == "0.2.0"
  end

  test "a new version containing a major commit increments the major" do
    assert new_version("0.1.0", [break()]) == "1.0.0"
  end

  test "a new version containing a minor commit resets the patch" do
    assert new_version("0.1.1", [minor()]) == "0.2.0"
  end

  test "a new version containing a major commit resets the minor and patch" do
    assert new_version("0.1.1", [break()]) == "1.0.0"
  end

  test "build metadata can be set with the build option" do
    assert new_version("0.1.1", [break()], build: "150") == "1.0.0+150"
  end

  test "attempting to release when no commits would yield a new version number is an error" do
    assert_raise RuntimeError, ~r/No changes should result in a new release version./, fn ->
      new_version("0.1.1", [chore()])
    end
  end

  test "if changing the build metadata, a non-version change is not an error" do
    new_version("0.1.1+10", [chore()], build: "11")
  end

  test "if changing the pre_release, a non-version change is not an error" do
    new_version("0.1.1+10", [chore()], pre_release: "alpha")
  end

  test "if the force_patch option is present, no error is raised and the version is patched regardless" do
    assert new_version("0.1.1", [chore()], force_patch: true) == "0.1.2"
  end

  test "the force_patch option is present with a minor update results in minor bump" do
    assert new_version("0.1.1", [minor()], force_patch: true) == "0.2.0"
  end

  test "the force_patch option is present on an rc with a minor update results in minor bump" do
    assert new_version("0.1.1-rc1", [minor()], force_patch: true) == "0.2.0"
  end

  test "the force_patch and rc options are present on an rc with a patch results in an rc bump" do
    assert new_version("0.1.1-rc1", [patch()], rc: true, force_patch: true) == "0.1.1-rc2"
  end

  test "the force_patch option is present on an rc with a patch results in an patch bump" do
    assert new_version("0.1.1-rc1", [patch()], force_patch: true) == "0.1.2"
  end

  test "if the no_major option is present, a major change only updates the patch" do
    assert new_version("0.1.1", [break()], no_major: true) == "0.2.0"
  end

  test "if a pre_release is specified, you get the next version tagged with that pre-release with a minor change" do
    assert new_version("0.1.1", [minor()], pre_release: "alpha") == "0.2.0-alpha"
  end

  test "if a pre_release is specified, you get the next version tagged with that pre-release with a major change" do
    assert new_version("0.1.1", [break()], pre_release: "alpha") == "1.0.0-alpha"
  end

  test "if a pre_release is performed after a pre_release, and the version would not change then it is unchanged" do
    assert new_version("0.1.2-alpha", [patch()], pre_release: "beta") == "0.1.2-beta"
  end

  test "if a pre_release is performed after a pre_release, and the version would change, then it is changed" do
    assert new_version("0.1.2-alpha", [minor()], pre_release: "beta") == "0.2.0-beta"
  end

  test "if a pre_release is performed after using rc, and the version would change, then it is changed with pre-release" do
    assert new_version("0.1.2-rc0", [patch()], pre_release: "alpha") == "0.1.3-alpha"
  end

  test "a release candidate starts at 0 if requested on patch" do
    assert new_version("0.1.0", [patch()], rc: true) == "0.1.1-rc0"
  end

  test "a release candidate starts at 0 if requested on minor" do
    assert new_version("0.1.0", [minor()], rc: true) == "0.2.0-rc0"
  end

  test "a release candidate starts at 0 if requested on break" do
    assert new_version("0.1.0", [break()], rc: true) == "1.0.0-rc0"
  end

  test "a release candidate increments by one on patch" do
    assert new_version("0.1.1-rc0", [patch()], rc: true) == "0.1.1-rc1"
  end

  test "a release candidate resets on minor" do
    assert new_version("0.1.1-rc0", [minor()], rc: true) == "0.2.0-rc0"
  end

  test "a release candidate resets on major" do
    assert new_version("0.1.1-rc0", [break()], rc: true) == "1.0.0-rc0"
  end

  test "a release candidate raises correctly when it would not change" do
    assert_raise RuntimeError, ~r/No changes should result in a new release version./, fn ->
      new_version("0.1.1-rc0", [chore()], rc: true)
    end
  end

  test "invalid rc number version raises" do
    assert_raise RuntimeError, ~r/Found an rc version that could not be parsed/, fn ->
      new_version("0.1.1-rca", [patch()], rc: true)
    end
  end

  test "invalid rc label version raises" do
    assert_raise RuntimeError, ~r/Found an rc version that could not be parsed/, fn ->
      new_version("0.1.1-releasecandidate", [patch()], rc: true)
    end
  end

  test "no prefix on version raises" do
    assert_raise ArgumentError,
                 ~r/Expected: .+ to be parseable as a version, but it was not/,
                 fn ->
                   new_version("v0.1.1", [patch()], rc: true, prefix: "vv")
                 end
  end

  test "last valid non rc is found correctly without prefixes" do
    versions = ["0.0.1", "0.1.0-rc0", "0.1.0", "0.2.0-alpha"]
    last_rc = Version.last_valid_non_rc_version(versions, "")

    assert last_rc == "0.1.0"
  end

  test "last valid non rc is found correctly with prefixes" do
    versions = ["v0.0.1", "v0.1.0-rc0", "0.1.0", "0.2.0-alpha"]
    last_rc = Version.last_valid_non_rc_version(versions, "v")

    assert last_rc == "v0.0.1"
  end

  test "last_version_greater_than is found correctly without prefixes" do
    versions = ["0.0.1", "0.1.0-rc0", "0.1.0", "0.1.1", "0.2.0-alpha"]
    last_version_after = Version.last_version_greater_than(versions, "0.1.0", "")

    assert last_version_after == "0.1.1"
  end
end
