defmodule GitOps.MixProject do
  use Mix.Project

  @version "0.1.1-rc0"

  def project do
    [
      app: :git_ops,
      version: @version,
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:git_cli, "~> 0.2"},
      {:nimble_parsec, "~> 0.2"}
    ]
  end
end
