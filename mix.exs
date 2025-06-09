defmodule GitOps.MixProject do
  use Mix.Project

  @source_url "https://github.com/zachdaniel/git_ops"
  @version "2.9.0"

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
      source_url: @source_url,
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "coveralls.travis": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      aliases: [interactive_tasks: ["test", "credo"]]
    ]
  end

  defp description do
    """
    A tool for managing the version and changelog of a project using conventional commits.
    """
  end

  defp package do
    [
      name: :git_ops,
      maintainers: "Zach Daniel",
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:mix_test_interactive, "~> 4.0", only: :dev, runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:excoveralls, "~> 0.6", only: :test},
      {:git_cli, "~> 0.2"},
      {:igniter, "~> 0.5 and >= 0.5.27", only: [:dev, :test]},
      {:nimble_parsec, "~> 1.0"},
      {:req, "~> 0.5"}
    ]
  end
end
