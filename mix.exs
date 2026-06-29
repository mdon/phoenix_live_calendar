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
      dialyzer: [plt_add_apps: [:mix]],
      # Core (views, components, utils, data structs, store logic, install task) is
      # ~90%+; the residual below this floor is the optional Ecto migration DDL,
      # which is only exercisable against a real Postgres repo (kept out of the
      # default suite so the optional dep never forces a database on contributors).
      test_coverage: [summary: [threshold: 80]],
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
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        Views: [
          PhoenixLiveSchedule.Views.MonthGrid,
          PhoenixLiveSchedule.Views.WeekGrid,
          PhoenixLiveSchedule.Views.DayView,
          PhoenixLiveSchedule.Views.NDayView,
          PhoenixLiveSchedule.Views.YearView,
          PhoenixLiveSchedule.Views.Agenda,
          PhoenixLiveSchedule.Views.Timeline,
          PhoenixLiveSchedule.Views.ResourceView
        ],
        Components: [
          PhoenixLiveSchedule.CalendarComponent,
          PhoenixLiveSchedule.Components.EventItem,
          PhoenixLiveSchedule.Components.EventPopover,
          PhoenixLiveSchedule.Components.Header,
          PhoenixLiveSchedule.Components.MiniCalendar,
          PhoenixLiveSchedule.Components.TimeGutter
        ],
        "Data structures": [
          PhoenixLiveSchedule.Event,
          PhoenixLiveSchedule.Resource,
          PhoenixLiveSchedule.Availability,
          PhoenixLiveSchedule.BookingConfig,
          PhoenixLiveSchedule.DayMarker,
          PhoenixLiveSchedule.Eventable
        ],
        Persistence: [
          PhoenixLiveSchedule.Store.EventStore,
          PhoenixLiveSchedule.Store.Ecto.EventStoreEcto,
          PhoenixLiveSchedule.Store.Ecto.EventSchema,
          PhoenixLiveSchedule.Store.Ecto.Migrations,
          PhoenixLiveSchedule.Store.Ecto.RepoHelper
        ],
        Utilities: [
          PhoenixLiveSchedule.PubSub,
          PhoenixLiveSchedule.Utils.DateHelpers,
          PhoenixLiveSchedule.Utils.TimeSlots,
          PhoenixLiveSchedule.Utils.OverlapLayout,
          PhoenixLiveSchedule.Utils.Constraints,
          PhoenixLiveSchedule.Utils.I18n,
          PhoenixLiveSchedule.Utils.Telemetry
        ]
      ]
    ]
  end

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": ["format --check-formatted", "credo --strict", "dialyzer"]
    ]
  end
end
