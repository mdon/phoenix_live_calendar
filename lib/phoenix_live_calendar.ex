defmodule PhoenixLiveCalendar do
  @moduledoc """
  A comprehensive calendar and scheduling component library for Phoenix LiveView.

  PhoenixLiveCalendar provides server-rendered calendar views (month, week, day, year,
  N-day, agenda, timeline, resource) with optional JavaScript hooks for drag
  interactions, optional PubSub for real-time sync, and optional Ecto persistence.

  ## Quick start

      # In your LiveView template
      <.live_component
        module={PhoenixLiveCalendar.CalendarComponent}
        id="my-calendar"
        events={@events}
        on_date_select={fn date -> send(self(), {:date_selected, date}) end}
        on_event_click={fn id -> send(self(), {:event_clicked, id}) end}
      />

  ## Architecture

  PhoenixLiveCalendar is built in layers, each optional:

  - **Layer 0** — Pure Elixir/HEEx views (zero JS required)
  - **Layer 1** — JS hooks for drag-to-select, drag-to-move, resize
  - **Layer 2** — PubSub for real-time multi-user updates
  - **Layer 3** — Booking constraints (availability, slots, buffers)
  - **Layer 4** — Ecto persistence (optional, Oban-style migrations)

  ## Views

  | View | Module | Description |
  |------|--------|-------------|
  | Month | `PhoenixLiveCalendar.Views.MonthGrid` | Traditional 42-cell grid |
  | Week | `PhoenixLiveCalendar.Views.WeekGrid` | 7 days with time axis |
  | Day | `PhoenixLiveCalendar.Views.DayView` | Single day time grid |
  | N-day | `PhoenixLiveCalendar.Views.NDayView` | Configurable day count |
  | Year | `PhoenixLiveCalendar.Views.YearView` | 12 mini-months |
  | Agenda | `PhoenixLiveCalendar.Views.Agenda` | Chronological list |
  | Timeline | `PhoenixLiveCalendar.Views.Timeline` | Horizontal time, resource rows |
  | Resource | `PhoenixLiveCalendar.Views.ResourceView` | Resource columns |

  > #### View maturity {: .info}
  >
  > All eight views render server-side and are usable today. **Month** is the most
  > polished — it is the primary view and the one tuned for small screens. The
  > remaining views (week, day, N-day, year, agenda, timeline, resource) are
  > functional but less refined; in particular the time-grid views are not yet
  > optimised for phone widths. Expect them to gain polish in later releases.

  ## Data structures

  - `PhoenixLiveCalendar.Event` — Calendar events
  - `PhoenixLiveCalendar.Resource` — Rooms, people, equipment
  - `PhoenixLiveCalendar.Availability` — Business hours, available windows
  - `PhoenixLiveCalendar.BookingConfig` — Slot constraints and rules

  ## CSS setup

  Add to your `assets/css/app.css`:

      @source "../../deps/phoenix_live_calendar";

  ## JS hooks setup (optional)

  Add to your `assets/js/app.js`:

      import "../../deps/phoenix_live_calendar/priv/static/assets/phoenix_live_calendar.js"

      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: { ...window.PhoenixLiveCalendarHooks, ...Hooks }
      })
  """

  alias PhoenixLiveCalendar.{Availability, BookingConfig, DayMarker, Event, Resource}

  @doc """
  Returns whether PhoenixLiveCalendar CSS integration has been wired up.

  Looks for the package name in the common `app.css` locations **and** in any
  `assets/css/*.css` — so it also recognises a generated Tailwind sources file
  (e.g. PhoenixKit's `_phoenix_kit_sources.css`, which `@source`s the package
  automatically). Used at compile time to warn developers who haven't run
  `mix phoenix_live_calendar.install` and aren't wiring it some other way.
  """
  @spec installed?() :: boolean()
  def installed? do
    (["assets/css/app.css", "priv/static/assets/app.css", "assets/app.css"] ++
       Path.wildcard("assets/css/*.css"))
    |> Enum.uniq()
    |> Enum.any?(fn path ->
      case File.read(path) do
        {:ok, content} -> String.contains?(content, "phoenix_live_calendar")
        _ -> false
      end
    end)
  end

  @doc """
  Creates a new event struct.

  ## Examples

      PhoenixLiveCalendar.event("1", ~D[2026-04-01], title: "My Event")
      PhoenixLiveCalendar.event("2", ~U[2026-04-01 10:00:00Z], title: "Meeting", end: ~U[2026-04-01 11:00:00Z])
  """
  @spec event(term(), Date.t() | DateTime.t() | NaiveDateTime.t(), keyword()) :: Event.t()
  def event(id, start, opts \\ []) do
    struct!(Event, [{:id, id}, {:start, start} | opts])
  end

  @doc """
  Creates a new resource struct.

  ## Examples

      PhoenixLiveCalendar.resource("room-a", "Conference Room A")
      PhoenixLiveCalendar.resource("dr-smith", "Dr. Smith", type: :person, color: "bg-accent")
  """
  @spec resource(term(), String.t(), keyword()) :: Resource.t()
  def resource(id, title, opts \\ []) do
    struct!(Resource, [{:id, id}, {:title, title} | opts])
  end

  @doc """
  Creates an availability window.

  ## Examples

      # Monday through Friday, 9am to 5pm
      PhoenixLiveCalendar.availability([1, 2, 3, 4, 5], ~T[09:00:00], ~T[17:00:00])

      # Specific date override
      PhoenixLiveCalendar.availability(~D[2026-04-15], ~T[10:00:00], ~T[14:00:00])
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

      PhoenixLiveCalendar.booking_config(duration: 30, buffer_after: 5, min_notice: 60)
  """
  @spec booking_config(keyword()) :: BookingConfig.t()
  def booking_config(opts \\ []) do
    struct!(BookingConfig, opts)
  end

  @doc """
  Creates a day marker (date annotation).

  ## Examples

      # Holiday
      PhoenixLiveCalendar.day_marker("xmas", "Christmas Day", ~D[2026-12-25], type: :holiday, available: false)

      # Multi-day notice
      PhoenixLiveCalendar.day_marker("winter", "Winter Hours", ~D[2026-12-20],
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

  Items that already are `PhoenixLiveCalendar.Event` structs pass through unchanged.
  """
  @spec to_events([term()]) :: [Event.t()]
  def to_events(items) do
    Enum.map(items, &PhoenixLiveCalendar.Eventable.to_event/1)
  end
end
