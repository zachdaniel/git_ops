defmodule GitOps.MixProject do
  use Mix.Project

  @version "0.7.0"

  def project do
    [
      app: :git_ops,
      version: @version,
      elixir: "~> 1.6",
      description: description(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      name: "Git Ops",
      docs: docs(),
      source_url: "https://github.com/spandex-project/spandex",
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "coveralls.travis": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp description() do
    """
    A tool for managing the version and changelog of a project using conventional commits.
    """
  end

  defp package() do
    [
      name: :git_ops,
      maintainers: "Zachary Daniel",
      licenses: ["MIT License"],
      links: %{
        "GitHub" => "https://github.com/zachdaniel/git_ops"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md"
      ]
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
      {:credo, "~> 0.10.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:excoveralls, "~> 0.6", only: :test},
      {:git_cli, "~> 0.2"},
      {:inch_ex, "~> 0.5", only: [:dev, :test]},
      {:nimble_parsec, "~> 0.4"}
    ]
  end
end
