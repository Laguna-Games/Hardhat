defmodule Hardhat.Mixfile do
  use Mix.Project

  def project do
    [
      app: :hardhat,
      version: "1.0.0",
      build_path: "_build",
      config_path: "config/config.exs",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.14.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: elixirc_options(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.lcov": :test,
        check: :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Hardhat.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Always generate debug information.
  defp elixirc_options(_), do: [debug_info: true]

  defp aliases do
    [
      test: "test --no-start",

      # Strict compliance checking.
      check: [
        "deps.compile",
        "compile --warnings-as-errors",
        "mix format --check-formatted",
        "test --raise",
        "credo -a --strict",
        "dialyzer --no-check --quiet"
      ]
    ]
  end

  defp deps do
    [
      {:poison, "~> 5.0"},

      # Static analysis and type checking.
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},

      # Code coverage.
      {:excoveralls, ">= 0.0.0", only: :test}
    ]
  end

  defp dialyzer do
    [
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]
  end

  defp docs do
    [
      extras: extras()
    ]
  end

  defp extras do
    []
  end
end
