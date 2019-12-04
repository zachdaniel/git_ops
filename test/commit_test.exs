defmodule GitOps.Test.CommitTest do
  use ExUnit.Case

  alias GitOps.Commit

  defp format!(message) do
    message
    |> parse!()
    |> Commit.format()
  end

  defp parse!(message) do
    {:ok, commit} = Commit.parse(message)

    commit
  end

  test "a simple feature is parsed with the correct type" do
    assert parse!("feat: An awesome new feature!").type == "feat"
  end

  test "a simple feature is parsed with the correct message" do
    assert parse!("feat: An awesome new feature!").message == "An awesome new feature!"
  end

  @tag :regression
  test "a breaking change via a prefixed exclamation mark fails to parse" do
    assert Commit.parse("!feat: A breaking change") == :error
  end

  test "a breaking change via a postfixed exclamation mark is parsed as a breaking change" do
    assert parse!("feat!: A breaking change").breaking?
  end

  test "a breaking change via a postfixed exclamation mark after a scope is parsed as a breaking change" do
    assert parse!("feat(stuff)!: A breaking change").breaking?
  end

  test "a simple feature is formatted correctly" do
    assert format!("feat: An awesome new feature!") == "* An awesome new feature!"
  end

  test "a breaking change does not include the exclamation mark in the formatted version" do
    assert format!("feat!: An awesome new feature!") == "* An awesome new feature!"
  end
end
