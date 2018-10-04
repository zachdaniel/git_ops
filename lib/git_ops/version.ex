defmodule GitOps.Version do
  def first_valid_version(versions) do
    Enum.find(versions, fn version ->
      match?({:ok, _}, Version.parse(version))
    end)
  end
end
