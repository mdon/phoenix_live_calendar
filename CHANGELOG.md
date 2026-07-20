# Changelog

## 0.4.0

### Changed

- **Container-query sizing (behavior-changing — the reason this is 0.4.0):** the component root is now a CSS `@container`; the header and the month grid compact to the CALENDAR's width instead of the viewport's (`@2xl`/`@3xl`/`@5xl` tiers). A calendar in a narrow column on a wide screen now renders exactly like one on a phone. The root carries `w-full` — give the calendar a width-defining parent (see the new "Sizing" section in the `CalendarComponent` moduledoc); inside a shrink-to-fit context a container-queried element cannot size itself by its content. Standalone `<.month_grid>` is its own `@container`.
- The container no longer clips its children: `overflow-hidden` moved from `.cal-container` to the inner `.cal-view-container` (which rounds to the container's corners), so tooltip/popover bubbles of consumer controls in the toolbar slots are no longer swallowed at the calendar edge. Consumer note: `container-type: inline-size` makes the calendar the containing block for `position: fixed`/`absolute` descendants (a CSS containment side effect) — overlays inside the toolbar slots resolve their coordinates against the calendar box now.
- The header toolbar wraps on narrow containers instead of overflowing (the rigid three-zone grid resumes at `@2xl`); wings wrap; the title caps at `45cqw` while narrow.
- Month grid density tightens in narrow containers: 80px day cells (112/128px at `@3xl`/`@5xl`), compact day headers with narrow weekday names, slimmer all-day chips.

### Fixed

- Hiding weekends no longer misaligns month rows — dates chunk by the actual days-per-week instead of always 7, which bled two next-week days into every row.

### Added

- `DateHelpers.group_by_weeks/2` — optional `days_per_week` argument (default 7; `group_by_weeks/1` unchanged).


## 0.3.0

### Added

- **Heatmap** (`PhoenixLiveCalendar.Heatmap`): turn a `%{date => value}` map into intensity `DayMarker`s — `:linear` or `:quantile` scale (min-rank ties), named palettes (`:success`/`:heat`/`:cool`/`:mono`) or a custom class list, `:fill` (cell tint) or `:dot` (corner dot) style, label/`show_label`/`id_prefix` options. Renders in month, year (mini-calendar tints + dots), week and day.
- **Widgets** (`PhoenixLiveCalendar.Widgets`): compressed dashboard components — `next_events/1` (graded when-labels incl. "Ongoing"), `week_strip/1`, `activity_grid/1` (GitHub-style N-week strip), `activity_month/1` (one-month activity calendar), `mini_timeline/1` (fitted, axis-less today strip).
- **Layers**: `Layer` struct + `Event.layer_id`, a legend of server-side toggle chips, `hidden_layers`/`on_layers_change` on the component, and Ecto store migration **V2** adding `layer_id` (rerun `Migrations.up/1`).
- **Theme color tokens**: 8 daisyUI semantic atoms (`:primary`, `:secondary`, `:accent`, `:info`, `:success`, `:warning`, `:error`, `:neutral`) plus a `config :phoenix_live_calendar, :color_tokens` map, resolved everywhere through one `Theme.event_colors/2` merge rule. Raw class strings keep working.
- **Timeline pass**: `date_mode: :clamp | :filter` (midnight clamping of cross-day bars), `fit_to_events` visible window, sticky resource column, now indicator, `show_time_axis`, and bar labels via `label_position: :fit | :inside | :outside | :none` with server-side fit estimation and collision-aware outside placement.
- **Week/day focused pass**: day markers (header chips, column tints, heat dots), greedy all-day lane packing, height-tiered event content (detail → inline → title → none, via server-side rem estimation), `min_event_height`, `event_content`, events clamped to their day column and the visible hour window, phone-ready grid columns.
- **Resource view parity**: shared per-day segment rule, plural `resource_ids`, all-day blocks rendered under timed bookings, `today`/`now`/`dir`/`event_content`/`min_event_height`.
- **Slot forwarding** through `CalendarComponent`: `:event`, `:day_cell`, `:time_label`, `:resource_label`, `:resource_header`, `:day_header`, `:no_events`, and `toolbar_start`/`toolbar_end`.
- `events_mode: :window` — the component trims events to the visible range before rendering (for hosts that pass one big list).
- `now` attr on week/day/N-day/resource/timeline (dependency-injectable now-line), `today: :none` sentinel (archive views render no today decorations while navigation still anchors on real today).
- `header_layout: :auto | :centered | :start`, and the toolbar auto-collapses when it has no content.
- Cross-midnight booking validation: a booking is split at midnight and every day-segment must fit that day's availability windows.
- Event helpers: `first_date/1`, `in_range?/3`, `dates_overlap?/2`, `on_resource?/2`, `day_window/4` (the shared per-day segment rule).

### Changed

- **Timeline defaults are behavior-changing** (the reason this is 0.3.0): bars are clamped/filtered to the visible day window by default instead of drawing raw time-of-day geometry for cross-midnight events, and resource labels clip instead of overflowing.
- Event DOM ids are scoped per view instance, so the same event rendered by two views on one page no longer collides.
- Mini-calendar event dots sit below the date pill and use the event's resolved color.
- RTL pass: geometry and decoration use logical properties (`inset-inline-start`, `border-s/e`, `rounded-s/e`, `ms/me`) throughout.

### Fixed

- `DayMarker` `color`/`text_color`/`class` are honored by the month grid (custom heatmap colors no longer silently dropped).
- Duplicate ticker DOM ids across the days of a multi-day marker, and `MarkerTicker` re-syncs after LiveView patches (rotation survives navigation; hover-resume is cancelled by an external pause and re-armed on interval changes).
- Slot sharing between a midnight-crossing event and an event starting on the crosser's last day no longer swallows bars.
- The calendar opens on the viewer's month: `internal_date` seeds from the `today` attr.
- A `slot_duration <= 0` no longer hangs the renderer in an infinite stream.
- `show_today_button: false` actually hides the button; the n-day view switcher round-trips; every documented view option is reachable through `CalendarComponent`.
- Layer visibility survives layer-list reloads (stale ids intersect at filter time; seeding happens once, on the first non-empty list).
- Header `:start` layout keeps its wing content; heatmap quantile ties stay in their bucket; week/agenda boundary events land on the right side of midnight; all-day `DateTime` events occupy the right days.

## 0.2.0

### Added

- `respect_hours` mode (month view): timed events cover only the hours they occupy — single-day events become inset bars sized to their duration; multi-day bars trim their boundary days to their start/end hours. Very short events keep a 1-hour minimum width so they stay visible. Opt-in (default off); all-day events and a custom `:event` slot are unaffected. Threaded through `CalendarComponent`.
- `Event.spans_multiple_dates?/1` and `Event.last_date/1` — the date-occupancy source of truth for bar rendering.

### Changed

- Month view renders any event spanning 2+ calendar dates as one continuous bar, including overnight timed events (e.g. 10pm→2am), instead of a chip per day.

### Fixed

- No stray stub on the day after a multi-day timed event ends (the last day is capped to the date the event actually ends on).
- Color-less events get a legible default background instead of an unreadable inherited one.
- Duplicate DOM ids when a single event renders across multiple day cells.

## 0.1.0

- Initial release
- Layer 0: Pure Elixir/HEEx calendar views (month, week, day, N-day, year, agenda, timeline, resource)
- Layer 1: Optional JS hooks (drag-to-select, drag-to-move, resize, responsive container, marker ticker)
- Layer 2: Optional PubSub integration for real-time updates
- Layer 3: Booking constraints (availability, slots, buffers, validation)
- Layer 4: Optional Ecto persistence layer
- Core data structures: Event, Resource, Availability, BookingConfig, DayMarker
- Accessibility-focused: ARIA grid roles + semantic labels (arrow-key grid navigation and focus restoration are on the roadmap)
- RTL support
- i18n via default English labels + an override translations map (supply your app's Gettext strings directly)
- Tailwind CSS / daisyUI compatible styling
- Responsive month view tuned for small screens (single-letter day headers, equal-width columns that never overflow). The other views are functional but less polished — the time-grid views are not yet optimised for phone widths
