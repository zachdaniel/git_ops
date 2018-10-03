defmodule GitOpsTest do
  use ExUnit.Case
  doctest GitOps

  test "greets the world" do
    assert GitOps.hello() == :world
  end
end
