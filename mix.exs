defmodule PhoenixLiveCalendar.MixProject do
  use Mix.Project

  @version "0.3.0"
  @description "A comprehensive calendar and scheduling component library for Phoenix LiveView"
  @source_url "https://github.com/mdon/phoenix_live_calendar"

  def project do
    [
      app: :phoenix_live_calendar,
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
      name: "PhoenixLiveCalendar",
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
      name: "phoenix_live_calendar",
      maintainers: ["mdon"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv mix.exs README.md LICENSE CHANGELOG.md .formatter.exs)
    ]
  end

  defp docs do
    [
      name: "PhoenixLiveCalendar",
      source_ref: "v#{@version}",
      source_url: @source_url,
      main: "PhoenixLiveCalendar",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        Views: [
          PhoenixLiveCalendar.Views.MonthGrid,
          PhoenixLiveCalendar.Views.WeekGrid,
          PhoenixLiveCalendar.Views.DayView,
          PhoenixLiveCalendar.Views.NDayView,
          PhoenixLiveCalendar.Views.YearView,
          PhoenixLiveCalendar.Views.Agenda,
          PhoenixLiveCalendar.Views.Timeline,
          PhoenixLiveCalendar.Views.ResourceView
        ],
        Components: [
          PhoenixLiveCalendar.CalendarComponent,
          PhoenixLiveCalendar.Components.EventItem,
          PhoenixLiveCalendar.Components.EventPopover,
          PhoenixLiveCalendar.Components.Header,
          PhoenixLiveCalendar.Components.MiniCalendar,
          PhoenixLiveCalendar.Components.TimeGutter
        ],
        "Data structures": [
          PhoenixLiveCalendar.Event,
          PhoenixLiveCalendar.Resource,
          PhoenixLiveCalendar.Availability,
          PhoenixLiveCalendar.BookingConfig,
          PhoenixLiveCalendar.DayMarker,
          PhoenixLiveCalendar.Eventable
        ],
        Persistence: [
          PhoenixLiveCalendar.Store.EventStore,
          PhoenixLiveCalendar.Store.Ecto.EventStoreEcto,
          PhoenixLiveCalendar.Store.Ecto.EventSchema,
          PhoenixLiveCalendar.Store.Ecto.Migrations,
          PhoenixLiveCalendar.Store.Ecto.RepoHelper
        ],
        Utilities: [
          PhoenixLiveCalendar.PubSub,
          PhoenixLiveCalendar.Utils.DateHelpers,
          PhoenixLiveCalendar.Utils.TimeSlots,
          PhoenixLiveCalendar.Utils.OverlapLayout,
          PhoenixLiveCalendar.Utils.Constraints,
          PhoenixLiveCalendar.Utils.I18n,
          PhoenixLiveCalendar.Utils.Telemetry
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
