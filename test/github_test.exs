defmodule GitOps.Test.GitHubTest do
  use ExUnit.Case

  alias GitOps.GitHub

  describe "fetch_user_from_api/1" do
    test "rejects an email carrying search-query qualifiers instead of resolving it" do
      assert {:error, _} = GitHub.fetch_user_from_api("torvalds in:login")
    end

    test "rejects emails with whitespace or missing an @" do
      assert {:error, _} = GitHub.fetch_user_from_api("no-at-sign")
      assert {:error, _} = GitHub.fetch_user_from_api("a@b user:someone")
    end

    test "rejects a nil / non-binary email" do
      assert {:error, _} = GitHub.fetch_user_from_api(nil)
    end
  end
end
