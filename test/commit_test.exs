defmodule GitOps.Test.CommitTest do
  use ExUnit.Case

  alias GitOps.Commit

  defp format_one!(message) do
    message
    |> parse_one!()
    |> Commit.format()
  end

  defp parse_one!(message) do
    {:ok, [commit]} = Commit.parse(message)

    commit
  end

  defp parse_many!(message) do
    {:ok, commits} = Commit.parse(message)

    commits
  end

  describe "format_author/3" do
    test "formats GitHub noreply email with ID" do
      assert Commit.format_author("John Doe", "12345678+johndoe@users.noreply.github.com", nil) ==
               "johndoe"
    end

    test "formats standard GitHub noreply email" do
      assert Commit.format_author("John Doe", "johndoe@users.noreply.github.com", nil) ==
               "johndoe"
    end

    test "formats regular name by removing spaces" do
      assert Commit.format_author("John Doe", "john.doe@example.com", nil) == "John Doe"
    end

    test "returns empty string for nil values" do
      assert Commit.format_author(nil, "email@example.com", nil) == ""
      assert Commit.format_author("Name", nil, nil) == ""
      assert Commit.format_author(nil, nil, nil) == ""
    end

    test "uses GitHub username when provided" do
      assert Commit.format_author("John Doe", "john@example.com", %{username: "johndoe"}) ==
               "@johndoe"

      assert Commit.format_author("John Doe", "john@example.com", %{
               username: "johndoe",
               url: "a@b.com"
             }) ==
               "[@johndoe](a@b.com)"
    end

    test "falls back when no GitHub username" do
      assert Commit.format_author("John Doe", "john@example.com", nil) == "John Doe"
    end
  end

  test "a simple feature is parsed with the correct type" do
    assert parse_one!("feat: An awesome new feature!").type == "feat"
  end

  test "a simple feature is parsed with the correct message" do
    assert parse_one!("feat: An awesome new feature!").message == "An awesome new feature!"
  end

  @tag :regression
  test "a breaking change via a prefixed exclamation mark fails to parse" do
    assert Commit.parse("!feat: A breaking change") == :error
  end

  test "a breaking change via a postfixed exclamation mark is parsed as a breaking change" do
    assert parse_one!("feat!: A breaking change").breaking?
  end

  test "a breaking change via a postfixed exclamation mark after a scope is parsed as a breaking change" do
    assert parse_one!("feat(stuff)!: A breaking change").breaking?
  end

  test "a simple feature is formatted correctly" do
    assert format_one!("feat: An awesome new feature!") == "* An awesome new feature!"
  end

  test "a breaking change does not include the exclamation mark in the formatted version" do
    assert format_one!("feat!: An awesome new feature!") == "* An awesome new feature!"
  end

  test "multiple messages can be parsed from a commit" do
    text = """
    fix: fixed a bug

    some text about it

    some even more data about it

    improvement: improved a thing

    some other text about it

    some even more text about it
    """

    assert [
             %Commit{
               message: "fixed a bug",
               body: "some text about it",
               footer: "some even more data about it"
             },
             %Commit{
               message: "improved a thing",
               body: "some other text about it",
               footer: "some even more text about it"
             }
           ] = parse_many!(text)
  end

  test "includes author information in formatted commit" do
    commit = %Commit{
      type: "feat",
      message: "add new feature",
      author_name: "John Doe",
      author_email: "johndoe@users.noreply.github.com",
      github_user_data: nil
    }

    assert Commit.format(commit) == "* add new feature by johndoe"
  end

  test "includes GitHub username when available" do
    commit = %Commit{
      type: "feat",
      message: "add new feature",
      author_name: "John Doe",
      author_email: "john.doe@example.com",
      github_user_data: %{
        username: "johndoe"
      }
    }

    assert Commit.format(commit) == "* add new feature by @johndoe"
  end

  test "formats commit without author information when not available" do
    commit = %Commit{
      type: "feat",
      message: "add new feature"
    }

    assert Commit.format(commit) == "* add new feature"
  end

  test "formats commit with PR information" do
    commit = %Commit{
      type: "feat",
      message: "add new feature",
      pr_info: %{number: 123, url: "https://github.com/johndoe/repo/pull/123"}
    }

    assert Commit.format(commit) ==
             "* add new feature [(#123)](https://github.com/johndoe/repo/pull/123)"
  end

  test "formats commit with PR information and author information" do
    commit = %Commit{
      type: "feat",
      message: "add new feature",
      author_name: "John Doe",
      author_email: "john.doe@example.com",
      github_user_data: %{
        username: "johndoe"
      },
      pr_info: %{number: 123, url: "https://github.com/johndoe/repo/pull/123"}
    }

    assert Commit.format(commit) ==
             "* add new feature by @johndoe [(#123)](https://github.com/johndoe/repo/pull/123)"
  end
end
