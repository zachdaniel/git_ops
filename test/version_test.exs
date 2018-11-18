defmodule GitOps.Test.VersionTest do
  use ExUnit.Case

  defp new_version(current_version, commits, opts \\ []) do
    {prefix, opts} = Keyword.pop(opts, :prefix)

    GitOps.Version.determine_new_version(current_version, prefix || "", commits, opts)
  end

  defp minor() do
    %GitOps.Commit{
      type: "feat",
      message: "feat"
    }
  end

  defp patch() do
    %GitOps.Commit{
      type: "fix",
      message: "fix"
    }
  end

  defp chore() do
    %GitOps.Commit{
      type: "chore",
      message: "chore"
    }
  end

  defp break() do
    %{minor() | breaking?: true}
  end

  test "many things" do
    current_version = "1.2.2"
    current_version_rc = current_version <> "-rc2"
    current_version_pre = current_version <> "-a"

    major_bump = "2.0.0"
    minor_bump = "1.3.0"
    patch_bump = "1.2.3"

    assert new_version(current_version, [chore()], force_patch: true) == patch_bump
    assert new_version(current_version, [patch()], force_patch: true) == patch_bump
    assert new_version(current_version, [minor()], force_patch: true) == minor_bump
    assert new_version(current_version, [break()], force_patch: true) == major_bump

    assert new_version(current_version_rc, [chore()], force_patch: true) == patch_bump
    assert new_version(current_version_rc, [patch()], force_patch: true) == patch_bump
    assert new_version(current_version_rc, [minor()], force_patch: true) == minor_bump
    assert new_version(current_version_rc, [break()], force_patch: true) == major_bump

    assert new_version(current_version, [chore()], force_patch: true, rc: true) ==
             patch_bump <> "-rc0"

    assert new_version(current_version, [patch()], force_patch: true, rc: true) ==
             patch_bump <> "-rc0"

    assert new_version(current_version, [minor()], force_patch: true, rc: true) ==
             minor_bump <> "-rc0"

    assert new_version(current_version, [break()], force_patch: true, rc: true) ==
             major_bump <> "-rc0"

    assert_raise RuntimeError, ~r/No changes should result in a new release version./, fn ->
      new_version(current_version_rc, [chore()], rc: true)
    end

    assert new_version(current_version_rc, [patch()], rc: true) == current_version <> "-rc3"
    assert new_version(current_version_rc, [minor()], rc: true) == minor_bump <> "-rc0"
    assert new_version(current_version_rc, [break()], rc: true) == major_bump <> "-rc0"

    assert_raise RuntimeError, ~r/No changes should result in a new release version./, fn ->
      new_version(current_version, [chore()], pre_release: "a")
    end

    assert new_version(current_version, [patch()], pre_release: "a") == patch_bump <> "-a"
    assert new_version(current_version, [minor()], pre_release: "a") == minor_bump <> "-a"
    assert new_version(current_version, [break()], pre_release: "a") == major_bump <> "-a"

    assert_raise RuntimeError, ~r/No changes should result in a new release version./, fn ->
      new_version(current_version_pre, [chore()], pre_release: "b")
    end

    assert new_version(current_version_pre, [patch()], pre_release: "b") ==
             current_version <> "-b"

    assert new_version(current_version_pre, [minor()], pre_release: "b") == minor_bump <> "-b"
    assert new_version(current_version_pre, [break()], pre_release: "b") == major_bump <> "-b"

    assert new_version(current_version, [chore()], force_patch: true, pre_release: "a") ==
             patch_bump <> "-a"

    assert new_version(current_version, [patch()], force_patch: true, pre_release: "a") ==
             patch_bump <> "-a"

    assert new_version(current_version, [minor()], force_patch: true, pre_release: "a") ==
             minor_bump <> "-a"

    assert new_version(current_version, [break()], force_patch: true, pre_release: "a") ==
             major_bump <> "-a"

    assert new_version(current_version_rc, [chore()], force_patch: true, pre_release: "a") ==
             patch_bump <> "-a"

    assert new_version(current_version_rc, [patch()], force_patch: true, pre_release: "a") ==
             patch_bump <> "-a"

    assert new_version(current_version_rc, [minor()], force_patch: true, pre_release: "a") ==
             minor_bump <> "-a"

    assert new_version(current_version_rc, [break()], force_patch: true, pre_release: "a") ==
             major_bump <> "-a"

    assert new_version(current_version_pre, [chore()], force_patch: true, pre_release: "b") ==
             current_version <> "-b"

    assert new_version(current_version_pre, [patch()], force_patch: true, pre_release: "b") ==
             current_version <> "-b"

    assert new_version(current_version_pre, [minor()], force_patch: true, pre_release: "b") ==
             minor_bump <> "-b"

    assert new_version(current_version_pre, [break()], force_patch: true, pre_release: "b") ==
             major_bump <> "-b"
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

  test "if a prefix is configured, it is ignored when searching for a tag" do
    assert new_version("v0.1.1", [break()], prefix: "v") == "v1.0.0"
  end
end
