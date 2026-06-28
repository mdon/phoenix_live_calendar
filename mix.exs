defmodule PhoenixLiveSchedule.MixProject do
  use Mix.Project

  @version "0.1.0"
  @description "A comprehensive calendar and scheduling component library for Phoenix LiveView"
  @source_url "https://github.com/mdon/phoenix_live_schedule"

  def project do
    [
      app: :phoenix_live_schedule,
      version: @version,
      description: @description,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      aliases: aliases(),
      name: "PhoenixLiveSchedule",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Required: Phoenix LiveView
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix, "~> 1.7"},

      # Optional: Ecto for persistence layer
      {:ecto_sql, "~> 3.10", optional: true},
      {:postgrex, "~> 0.17", optional: true},

      # Optional: JSON encoding
      {:jason, "~> 1.4"},

      # Development and testing
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp package do
    [
      name: "phoenix_live_schedule",
      maintainers: ["mdon"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv mix.exs README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end

  defp docs do
    [
      name: "PhoenixLiveSchedule",
      source_ref: "v#{@version}",
      source_url: @source_url,
      main: "PhoenixLiveSchedule",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": ["format --check-formatted", "credo --strict", "dialyzer"]
    ]
  end
end
