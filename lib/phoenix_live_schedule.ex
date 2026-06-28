defmodule PhoenixLiveSchedule do
  @moduledoc """
  A comprehensive calendar and scheduling component library for Phoenix LiveView.

  PhoenixLiveSchedule provides server-rendered calendar views (month, week, day, year,
  N-day, agenda, timeline, resource) with optional JavaScript hooks for drag
  interactions, optional PubSub for real-time sync, and optional Ecto persistence.

  ## Quick start

      # In your LiveView template
      <.live_component
        module={PhoenixLiveSchedule.CalendarComponent}
        id="my-calendar"
        events={@events}
        on_date_select={fn date -> send(self(), {:date_selected, date}) end}
        on_event_click={fn id -> send(self(), {:event_clicked, id}) end}
      />

  ## Architecture

  PhoenixLiveSchedule is built in layers, each optional:

  - **Layer 0** — Pure Elixir/HEEx views (zero JS required)
  - **Layer 1** — JS hooks for drag-to-select, drag-to-move, resize
  - **Layer 2** — PubSub for real-time multi-user updates
  - **Layer 3** — Booking constraints (availability, slots, buffers)
  - **Layer 4** — Ecto persistence (optional, Oban-style migrations)

  ## Views

  | View | Module | Description |
  |------|--------|-------------|
  | Month | `PhoenixLiveSchedule.Views.MonthGrid` | Traditional 42-cell grid |
  | Week | `PhoenixLiveSchedule.Views.WeekGrid` | 7 days with time axis |
  | Day | `PhoenixLiveSchedule.Views.DayView` | Single day time grid |
  | N-day | `PhoenixLiveSchedule.Views.NDayView` | Configurable day count |
  | Year | `PhoenixLiveSchedule.Views.YearView` | 12 mini-months |
  | Agenda | `PhoenixLiveSchedule.Views.Agenda` | Chronological list |
  | Timeline | `PhoenixLiveSchedule.Views.Timeline` | Horizontal time, resource rows |
  | Resource | `PhoenixLiveSchedule.Views.ResourceView` | Resource columns |

  ## Data structures

  - `PhoenixLiveSchedule.Event` — Calendar events
  - `PhoenixLiveSchedule.Resource` — Rooms, people, equipment
  - `PhoenixLiveSchedule.Availability` — Business hours, available windows
  - `PhoenixLiveSchedule.BookingConfig` — Slot constraints and rules

  ## CSS setup

  Add to your `assets/css/app.css`:

      @source "../../deps/phoenix_live_schedule";

  ## JS hooks setup (optional)

  Add to your `assets/js/app.js`:

      import "../../deps/phoenix_live_schedule/priv/static/assets/phoenix_live_schedule.js"

      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: { ...window.PhoenixLiveScheduleHooks, ...Hooks }
      })
  """

  alias PhoenixLiveSchedule.{Availability, BookingConfig, DayMarker, Event, Resource}

  @doc """
  Returns whether PhoenixLiveSchedule CSS integration has been installed.

  Checks common app.css locations for the PhoenixLiveSchedule source directive.
  Used at compile time to warn developers who forgot to run `mix phoenix_live_schedule.install`.
  """
  @spec installed?() :: boolean()
  def installed? do
    css_paths = [
      "assets/css/app.css",
      "priv/static/assets/app.css",
      "assets/app.css"
    ]

    Enum.any?(css_paths, fn path ->
      case File.read(path) do
        {:ok, content} -> String.contains?(content, "phoenix_live_schedule")
        _ -> false
      end
    end)
  end

  @doc """
  Creates a new event struct.

  ## Examples

      PhoenixLiveSchedule.event("1", ~D[2026-04-01], title: "My Event")
      PhoenixLiveSchedule.event("2", ~U[2026-04-01 10:00:00Z], title: "Meeting", end: ~U[2026-04-01 11:00:00Z])
  """
  @spec event(term(), Date.t() | DateTime.t() | NaiveDateTime.t(), keyword()) :: Event.t()
  def event(id, start, opts \\ []) do
    struct!(Event, [{:id, id}, {:start, start} | opts])
  end

  @doc """
  Creates a new resource struct.

  ## Examples

      PhoenixLiveSchedule.resource("room-a", "Conference Room A")
      PhoenixLiveSchedule.resource("dr-smith", "Dr. Smith", type: :person, color: "bg-accent")
  """
  @spec resource(term(), String.t(), keyword()) :: Resource.t()
  def resource(id, title, opts \\ []) do
    struct!(Resource, [{:id, id}, {:title, title} | opts])
  end

  @doc """
  Creates an availability window.

  ## Examples

      # Monday through Friday, 9am to 5pm
      PhoenixLiveSchedule.availability([1, 2, 3, 4, 5], ~T[09:00:00], ~T[17:00:00])

      # Specific date override
      PhoenixLiveSchedule.availability(~D[2026-04-15], ~T[10:00:00], ~T[14:00:00])
  """
  @spec availability([integer()] | Date.t(), Time.t(), Time.t(), keyword()) :: Availability.t()
  def availability(days_or_date, start_time, end_time, opts \\ [])

  def availability(%Date{} = date, start_time, end_time, opts) do
    struct!(Availability, [
      {:date, date},
      {:start_time, start_time},
      {:end_time, end_time}
      | opts
    ])
  end

  def availability(days, start_time, end_time, opts) when is_list(days) do
    struct!(Availability, [
      {:days_of_week, days},
      {:start_time, start_time},
      {:end_time, end_time}
      | opts
    ])
  end

  @doc """
  Creates a booking configuration.

  ## Examples

      PhoenixLiveSchedule.booking_config(duration: 30, buffer_after: 5, min_notice: 60)
  """
  @spec booking_config(keyword()) :: BookingConfig.t()
  def booking_config(opts \\ []) do
    struct!(BookingConfig, opts)
  end

  @doc """
  Creates a day marker (date annotation).

  ## Examples

      # Holiday
      PhoenixLiveSchedule.day_marker("xmas", "Christmas Day", ~D[2026-12-25], type: :holiday, available: false)

      # Multi-day notice
      PhoenixLiveSchedule.day_marker("winter", "Winter Hours", ~D[2026-12-20],
        end_date: ~D[2027-01-05],
        type: :notice,
        color: "bg-info/10",
        description: "Reduced hours: 10am-3pm"
      )
  """
  @spec day_marker(term(), String.t(), Date.t(), keyword()) :: DayMarker.t()
  def day_marker(id, label, start_date, opts \\ []) do
    struct!(DayMarker, [{:id, id}, {:label, label}, {:start_date, start_date} | opts])
  end

  @doc """
  Converts a list of items to events using the `Eventable` protocol.

  Items that already are `PhoenixLiveSchedule.Event` structs pass through unchanged.
  """
  @spec to_events([term()]) :: [Event.t()]
  def to_events(items) do
    Enum.map(items, &PhoenixLiveSchedule.Eventable.to_event/1)
  end
end
