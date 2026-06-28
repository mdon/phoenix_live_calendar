# LiveCalendar

A comprehensive calendar and scheduling component library for Phoenix LiveView.

Server-rendered calendar views with optional drag interactions, real-time PubSub sync, booking constraints, and Ecto persistence. Zero JavaScript required for the base layer.

## Features

- **9 view types**: Month, Week, Day, N-day (flexible), Year, Agenda, Timeline, Resource columns, custom duration
- **Pure Elixir base layer**: Works without any JavaScript
- **Progressive enhancement**: Optional JS hooks for drag-to-select, drag-to-move, resize
- **Real-time sync**: Optional PubSub integration for multi-user calendars
- **Booking system**: Availability windows, slot constraints, capacity, buffers, validation
- **Accessible**: WCAG AA compliant — ARIA grid, roving tabindex, keyboard navigation, screen reader support
- **RTL support**: Full right-to-left layout for Arabic, Hebrew, Persian, Urdu
- **i18n**: All labels translatable via Gettext or override map
- **Tailwind CSS**: Uses daisyUI semantic classes, works with any Tailwind theme
- **Optional Ecto**: Opt-in persistence with Oban-style versioned migrations
- **Dashboard-ready**: All components work at any container size

## Installation

Add `live_calendar` to your dependencies:

```elixir
def deps do
  [
    {:live_calendar, "~> 0.1.0"}
  ]
end
```

Add to your `assets/css/app.css` so Tailwind scans the component templates:

```css
@source "../../deps/live_calendar";
```

### Optional: JS hooks

For drag interactions, add to `assets/js/app.js`:

```javascript
import "../../deps/live_calendar/priv/static/assets/live_calendar.js"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...window.LiveCalendarHooks, ...Hooks }
})
```

### Optional: Ecto persistence

```elixir
# config/config.exs
config :live_calendar, repo: MyApp.Repo

# Generate and run the migration
mix ecto.gen.migration add_live_calendar
```

Edit the migration:

```elixir
defmodule MyApp.Repo.Migrations.AddLiveCalendar do
  use Ecto.Migration

  def up, do: LiveCalendar.Store.Ecto.Migrations.up(version: 1)
  def down, do: LiveCalendar.Store.Ecto.Migrations.down(version: 1)
end
```

## Quick Start

```elixir
defmodule MyAppWeb.CalendarLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    events = [
      LiveCalendar.event("1", ~U[2026-04-01 09:00:00Z],
        title: "Team Standup",
        end: ~U[2026-04-01 09:30:00Z],
        color: "bg-primary"
      ),
      LiveCalendar.event("2", ~D[2026-04-05],
        title: "Company Holiday",
        all_day: true,
        color: "bg-success"
      )
    ]

    {:ok, assign(socket, events: events)}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={LiveCalendar.CalendarComponent}
      id="my-calendar"
      events={@events}
      views={[:month, :week, :day, :agenda]}
      on_date_select={fn date -> send(self(), {:date_selected, date}) end}
      on_event_click={fn id -> send(self(), {:event_clicked, id}) end}
    />
    """
  end

  def handle_info({:date_selected, date}, socket) do
    IO.inspect(date, label: "Selected date")
    {:noreply, socket}
  end

  def handle_info({:event_clicked, event_id}, socket) do
    IO.inspect(event_id, label: "Clicked event")
    {:noreply, socket}
  end
end
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `view` | atom | `:month` | Initial view (`:month`, `:week`, `:day`, `:year`, `:agenda`, `:timeline`, `:resource`) |
| `views` | list | `[:month, :week, :day]` | Available views in the switcher |
| `date` | Date | today | Initial date |
| `week_start` | integer | `1` | First day of week (1=Mon, 7=Sun) |
| `min_time` | Time | `~T[00:00:00]` | Earliest visible time in grid |
| `max_time` | Time | `~T[23:59:59]` | Latest visible time in grid |
| `slot_duration` | integer | `30` | Time slot duration in minutes |
| `time_format` | atom | `:h24` | `:h24` or `:h12` |
| `show_week_numbers` | boolean | `false` | Show ISO week numbers |
| `show_weekends` | boolean | `true` | Show Saturday/Sunday |
| `max_events` | integer | `3` | Max events per month cell |
| `n_days` | integer | `4` | Number of days for N-day view |
| `dir` | atom | `:ltr` | Text direction (`:ltr` or `:rtl`) |
| `translations` | map | `%{}` | Label overrides |
| `business_hours` | list | `[]` | Availability windows to highlight |

## Callbacks

| Callback | Payload | Description |
|----------|---------|-------------|
| `on_date_select` | `Date.t()` | Date clicked |
| `on_time_select` | `%{date, time, datetime, resource_id}` | Time slot clicked |
| `on_event_click` | `event_id` | Event clicked |
| `on_view_change` | `%{view, date}` | View switched |
| `on_date_range_change` | `%{start, end, view, date}` | Visible range changed |

## Using Individual Views

You can use any view component standalone without the LiveComponent wrapper:

```elixir
<LiveCalendar.Views.MonthGrid.month_grid
  date={~D[2026-04-01]}
  events={@events}
  on_date_click={JS.push("date_clicked")}
/>

<LiveCalendar.Views.Agenda.agenda
  date={Date.utc_today()}
  events={@events}
  days={14}
/>
```

## License

MIT License - see [LICENSE](LICENSE) for details.
