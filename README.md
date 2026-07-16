# PhoenixLiveCalendar

A comprehensive calendar and scheduling component library for Phoenix LiveView.

Server-rendered calendar views with optional drag interactions, real-time PubSub sync, booking constraints, and Ecto persistence. Zero JavaScript required for the base layer.

## Phoenix-first — it looks right without JavaScript

This is the guiding principle: every view (month, week, day, N-day, year,
agenda, timeline, resource) is computed **in Elixir** and rendered as plain
HEEx + Tailwind over the LiveView socket — no charting JS, no `<canvas>`, and
nothing that has to boot on the client for the layout to be correct. The JS
hooks are **progressive enhancement only** (drag-to-select / move / resize, the
day-marker ticker, touch handling). With them absent the calendar still renders
and works: navigation, view switching, date/event clicks, and the detail
popover are all server-driven `phx-click`s, and a day with multiple markers
still shows its first marker (you only lose the cycling). Add the hooks for
richer interaction; never depend on them for the page to look right.

## Features

- **8 view types**: Month, Week, Day, N-day (flexible), Year, Agenda, Timeline, Resource columns
- **Pure Elixir base layer**: Works without any JavaScript
- **Progressive enhancement**: Optional JS hooks for drag-to-select, drag-to-move, resize
- **Real-time sync**: Optional PubSub integration for multi-user calendars
- **Booking system**: Availability windows, slot constraints, capacity, buffers, validation
- **Accessibility-minded**: ARIA grid roles, roving tabindex, and screen-reader labels (full arrow-key grid navigation + focus restoration are on the roadmap)
- **RTL support**: Full right-to-left layout for Arabic, Hebrew, Persian, Urdu
- **i18n**: All labels translatable via Gettext or override map
- **Tailwind CSS**: Uses daisyUI semantic classes, works with any Tailwind theme
- **Optional Ecto**: Opt-in persistence with Oban-style versioned migrations
- **Dashboard-ready**: All components work at any container size

> **View maturity:** All eight views render server-side and work today. **Month**
> is the most polished and the view tuned for small screens; the others are
> functional but less refined — in particular the time-grid views (week / day /
> N-day) are not yet optimised for phone widths.

## Installation

Add `phoenix_live_calendar` to your dependencies:

```elixir
def deps do
  [
    {:phoenix_live_calendar, "~> 0.2.0"}
  ]
end
```

Add to your `assets/css/app.css` so Tailwind scans the component templates:

```css
@source "../../deps/phoenix_live_calendar";
```

### Optional: JS hooks

For drag interactions, add to `assets/js/app.js`:

```javascript
import "../../deps/phoenix_live_calendar/priv/static/assets/phoenix_live_calendar.js"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...window.PhoenixLiveCalendarHooks, ...Hooks }
})
```

### Optional: Ecto persistence

```elixir
# config/config.exs
config :phoenix_live_calendar, repo: MyApp.Repo

# Generate and run the migration
mix ecto.gen.migration add_phoenix_live_calendar
```

Edit the migration:

```elixir
defmodule MyApp.Repo.Migrations.AddPhoenixLiveCalendar do
  use Ecto.Migration

  def up, do: PhoenixLiveCalendar.Store.Ecto.Migrations.up(version: 1)
  def down, do: PhoenixLiveCalendar.Store.Ecto.Migrations.down(version: 1)
end
```

## Quick Start

```elixir
defmodule MyAppWeb.CalendarLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    events = [
      PhoenixLiveCalendar.event("1", ~U[2026-04-01 09:00:00Z],
        title: "Team Standup",
        end: ~U[2026-04-01 09:30:00Z],
        color: "bg-primary"
      ),
      PhoenixLiveCalendar.event("2", ~D[2026-04-05],
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
      module={PhoenixLiveCalendar.CalendarComponent}
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
| `today` | Date | UTC today | Timezone-correct today; also seeds the starting month when `date` is unset |
| `now` | Time | UTC now | Wall-clock time for the now indicator; pass the viewer's local time with a timezone-correct `today` |
| `events_mode` | atom | `:full` | `:window` trims `events` to those occupying the visible range — pair with `on_date_range_change` for range-driven fetching |
| `layers` | list | `[]` | `Layer` structs — legend toggle chips; hidden layers' events are filtered server-side; events inherit their layer's color |
| `show_legend` | boolean | `true` | Hide the layer legend row |
| `day_markers` | list | `[]` | `DayMarker` structs — cell tints + corner labels; a marker's own `color`/`text_color`/`class`/`show_label: false` enable heatmap-style month views |
| `filter_to_date` | boolean | `true` | Timeline: only render events occupying the displayed date |
| `clamp_to_date` | boolean | `true` | Timeline: clamp midnight-crossing events to the displayed date (23:50→00:20 renders on both days correctly) |
| `sticky_resource_column` | boolean | `true` | Timeline: pin the resource label column during horizontal scroll |
| `fit_to_events` | boolean | `false` | Timeline: size the visible window to the rendered events (hour-rounded) instead of `min_time`/`max_time` |
| `show_now_indicator` | boolean | `true` | Current-time line in day/week/timeline views when showing today |

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
<PhoenixLiveCalendar.Views.MonthGrid.month_grid
  date={~D[2026-04-01]}
  events={@events}
  on_date_click={JS.push("date_clicked")}
/>

<PhoenixLiveCalendar.Views.Agenda.agenda
  date={Date.utc_today()}
  events={@events}
  days={14}
/>
```

## License

MIT License - see [LICENSE](LICENSE) for details.
