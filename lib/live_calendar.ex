defmodule LiveCalendar do
  @moduledoc """
  A comprehensive calendar and scheduling component library for Phoenix LiveView.

  LiveCalendar provides server-rendered calendar views (month, week, day, year,
  N-day, agenda, timeline, resource) with optional JavaScript hooks for drag
  interactions, optional PubSub for real-time sync, and optional Ecto persistence.

  ## Quick start

      # In your LiveView template
      <.live_component
        module={LiveCalendar.CalendarComponent}
        id="my-calendar"
        events={@events}
        on_date_select={fn date -> send(self(), {:date_selected, date}) end}
        on_event_click={fn id -> send(self(), {:event_clicked, id}) end}
      />

  ## Architecture

  LiveCalendar is built in layers, each optional:

  - **Layer 0** — Pure Elixir/HEEx views (zero JS required)
  - **Layer 1** — JS hooks for drag-to-select, drag-to-move, resize
  - **Layer 2** — PubSub for real-time multi-user updates
  - **Layer 3** — Booking constraints (availability, slots, buffers)
  - **Layer 4** — Ecto persistence (optional, Oban-style migrations)

  ## Views

  | View | Module | Description |
  |------|--------|-------------|
  | Month | `LiveCalendar.Views.MonthGrid` | Traditional 42-cell grid |
  | Week | `LiveCalendar.Views.WeekGrid` | 7 days with time axis |
  | Day | `LiveCalendar.Views.DayView` | Single day time grid |
  | N-day | `LiveCalendar.Views.NDayView` | Configurable day count |
  | Year | `LiveCalendar.Views.YearView` | 12 mini-months |
  | Agenda | `LiveCalendar.Views.Agenda` | Chronological list |
  | Timeline | `LiveCalendar.Views.Timeline` | Horizontal time, resource rows |
  | Resource | `LiveCalendar.Views.ResourceView` | Resource columns |

  ## Data structures

  - `LiveCalendar.Event` — Calendar events
  - `LiveCalendar.Resource` — Rooms, people, equipment
  - `LiveCalendar.Availability` — Business hours, available windows
  - `LiveCalendar.BookingConfig` — Slot constraints and rules

  ## CSS setup

  Add to your `assets/css/app.css`:

      @source "../../deps/live_calendar";

  ## JS hooks setup (optional)

  Add to your `assets/js/app.js`:

      import "../../deps/live_calendar/priv/static/assets/live_calendar.js"

      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: { ...window.LiveCalendarHooks, ...Hooks }
      })
  """

  alias LiveCalendar.{Availability, BookingConfig, DayMarker, Event, Resource}

  @doc """
  Returns whether LiveCalendar CSS integration has been installed.

  Checks common app.css locations for the LiveCalendar source directive.
  Used at compile time to warn developers who forgot to run `mix live_calendar.install`.
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
        {:ok, content} -> String.contains?(content, "live_calendar")
        _ -> false
      end
    end)
  end

  @doc """
  Creates a new event struct.

  ## Examples

      LiveCalendar.event("1", ~D[2026-04-01], title: "My Event")
      LiveCalendar.event("2", ~U[2026-04-01 10:00:00Z], title: "Meeting", end: ~U[2026-04-01 11:00:00Z])
  """
  @spec event(term(), Date.t() | DateTime.t() | NaiveDateTime.t(), keyword()) :: Event.t()
  def event(id, start, opts \\ []) do
    struct!(Event, [{:id, id}, {:start, start} | opts])
  end

  @doc """
  Creates a new resource struct.

  ## Examples

      LiveCalendar.resource("room-a", "Conference Room A")
      LiveCalendar.resource("dr-smith", "Dr. Smith", type: :person, color: "bg-accent")
  """
  @spec resource(term(), String.t(), keyword()) :: Resource.t()
  def resource(id, title, opts \\ []) do
    struct!(Resource, [{:id, id}, {:title, title} | opts])
  end

  @doc """
  Creates an availability window.

  ## Examples

      # Monday through Friday, 9am to 5pm
      LiveCalendar.availability([1, 2, 3, 4, 5], ~T[09:00:00], ~T[17:00:00])

      # Specific date override
      LiveCalendar.availability(~D[2026-04-15], ~T[10:00:00], ~T[14:00:00])
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

      LiveCalendar.booking_config(duration: 30, buffer_after: 5, min_notice: 60)
  """
  @spec booking_config(keyword()) :: BookingConfig.t()
  def booking_config(opts \\ []) do
    struct!(BookingConfig, opts)
  end

  @doc """
  Creates a day marker (date annotation).

  ## Examples

      # Holiday
      LiveCalendar.day_marker("xmas", "Christmas Day", ~D[2026-12-25], type: :holiday, available: false)

      # Multi-day notice
      LiveCalendar.day_marker("winter", "Winter Hours", ~D[2026-12-20],
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

  Items that already are `LiveCalendar.Event` structs pass through unchanged.
  """
  @spec to_events([term()]) :: [Event.t()]
  def to_events(items) do
    Enum.map(items, &LiveCalendar.Eventable.to_event/1)
  end
end
