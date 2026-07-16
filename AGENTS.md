# AGENTS.md

**PhoenixLiveCalendar** — A comprehensive, server-rendered calendar and scheduling component library for Phoenix LiveView. Supports day, week, month, year, N-day, agenda, timeline, and resource views. Optional JS hooks for drag interactions, optional PubSub for real-time sync, optional Ecto for persistence. Zero JavaScript required for the base layer.


## Overview

PhoenixLiveCalendar is a standalone Hex package with no framework dependencies beyond Phoenix LiveView. It is designed to work with any Phoenix app, and optionally integrates with PhoenixKit via a separate bridge package.

### Guiding philosophy: Phoenix-first — looks right without JavaScript

This is the load-bearing design rule (shared with its sibling `phoenix_live_gantt`): **everything renders correctly server-side; JS is progressive enhancement, never a layout dependency.** Every view is computed in Elixir and emitted as HEEx + Tailwind — no JS-measured layout, no client-built DOM. The only two hooks in the render path (`MarkerTicker`, `PopoverPause`) degrade gracefully: with JS off a day's first marker still shows (you lose only the cycling), and the popover is `:if={@show && @event}` server state (the hook just pauses tickers). All primary interactions — navigate, view-switch, date/event click, popover open/close — are server-driven `phx-click`s over the base LiveView socket. The drag/resize/touch/responsive hooks add interaction but the calendar must look and read correctly without them. **When adding anything, the no-hooks render must still look good** — if a feature only works with a hook, give it a sensible static fallback (as MarkerTicker does).

### Architecture: Layered

```
Layer 0: Pure Elixir/HEEx — server-rendered grids, phx-click interactions (zero JS)
Layer 1: Optional JS hooks — drag-to-select, drag-to-move, resize, ResizeObserver, marker ticker
Layer 2: Optional PubSub — pass a topic for real-time multi-user updates
Layer 3: Optional booking constraints — availability, slots, buffers, validation
Layer 4: Optional Ecto persistence — behaviour + default Ecto implementation
```

Each layer depends on the one below. Layer 0 works standalone.

### Package boundary

```
phoenix_live_calendar (Hex, standalone)        <- anyone can use
    ^
phoenix_kit_calendar (bridge)          <- optional, PhoenixKit users only
    ^
phoenix_kit (existing)
```


## Installation

Consumer workflow:

```bash
# 1. Add to mix.exs
{:phoenix_live_calendar, "~> 0.2.0"}

# 2. Install
mix deps.get
mix phoenix_live_calendar.install
```

`mix phoenix_live_calendar.install` automatically:
- Finds `app.css` (checks `assets/css/app.css`, `priv/static/assets/app.css`, `assets/app.css`)
- Adds `@source "../../deps/phoenix_live_calendar";` after the last existing `@source` line
- Finds `app.js` (checks `assets/js/app.js`, `assets/app.js`), adds the JS hook import after the last `import` line, and spreads `...window.PhoenixLiveCalendarHooks` into the LiveSocket `hooks: { … }` config **when there is exactly one** such object literal (anything else — e.g. `hooks: Hooks` — is left untouched and printed as a manual step, so it never corrupts app.js)
- Idempotent — safe to run multiple times (markers `/* PhoenixLiveCalendar CSS Integration */` + `// PhoenixLiveCalendar JS hooks`)
- Accepts `--css-path` and `--js-path` overrides

### JS Hook Setup (required for full functionality)

Add to `assets/js/app.js`:

```javascript
import "../../deps/phoenix_live_calendar/priv/static/assets/phoenix_live_calendar.js"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...window.PhoenixLiveCalendarHooks, ...Hooks }
})
```

Without this, the following features will not work:
- MarkerTicker (day marker cycling in month view)
- PopoverPause (ticker pauses when popover opens)
- Drag-to-select, drag-to-move, event resize
- ResponsiveContainer, TouchHandler

### Compile-time install check

If the consumer hasn't run `mix phoenix_live_calendar.install`, a compile-time warning is emitted:

```
warning: PhoenixLiveCalendar CSS integration not detected.
Run: mix phoenix_live_calendar.install
```

Suppress with: `config :phoenix_live_calendar, skip_install_check: true`

**This is critical** — without the `@source` directive, Tailwind purges all PhoenixLiveCalendar CSS classes and components render without any styling (no rounded corners, no colors, no layout).


## Development Workflow

```bash
mix format
mix compile --warnings-as-errors
mix credo --strict
mix test
mix dialyzer
```

## Pre-commit commands

```bash
mix format && mix compile --warnings-as-errors && mix credo --strict && mix test
```

## Current Status

**All layers implemented. ~597 tests passing. Zero warnings. Zero credo strict issues. Dialyzer clean.** (Counts drift — trust `mix test` output over this line.)

- ~40 Elixir source files, 1 Mix task, 2 asset files (JS + CSS), ~37 test files
- Layer 0 (Pure Elixir views): Complete — all 8 views
- Layer 1 (JS hooks): Complete — 9 hooks (incl. SyncAnimations)
- 0.3 wave (2026-07): Theme color tokens, Heatmap (+palettes/:dot),
  Widgets (next_events / week_strip / activity_grid / activity_month /
  mini_timeline), Layers + legend, slot forwarding through the component,
  events_mode :window, timeline label_position, week/day event_content
  ladder + day markers + all-day lanes, header auto-collapse,
  per-instance event ids, now attr, resource view parity, plural
  resource_ids — plus a two-phase quality sweep (in-house triage +
  external AI quorum)
- Layer 2 (PubSub): Complete
- Layer 3 (Booking constraints): Complete
- Layer 4 (Ecto): Complete
- Expert code review completed — all critical and major issues fixed
- PhoenixKit demo page created at `/admin/calendar-demo`
- Month view polish pass completed (visibility tiers, header redesign, color fixes, marker ticker, compact mode)


## Project Structure

```
phoenix_live_calendar/
  config/
    config.exs                          # skip_install_check: true for self-compilation

  lib/
    phoenix_live_calendar.ex                    # Main module — public API, installed?/0 check
    mix/
      tasks/
        phoenix_live_calendar.install.ex        # Mix task — adds @source to consumer's app.css

    phoenix_live_calendar/
      # --- Core Data Structures ---
      event.ex                          # Event struct — @enforce_keys [:id, :start]
                                        #   Fields: title, description, location, url, start, end, color, text_color, class,
                                        #   group_id, resource_id, resource_ids, category, rrule, recurrence_id, icon, badge, border_color
                                        #   Defaults: visibility (20), all_day (false), display (:auto), editable (true), overlap (true),
                                        #   status (:confirmed), transparency (:opaque), priority (:normal), urgency (:none), extra (%{})
                                        #   Visibility tiers: day≥10, week≥20, month≥30, year≥40 (opt-in via min_visibility on CalendarComponent)
                                        #   Helpers: visible_at?, all_day?, effective_end, duration_seconds, multi_day?, on_date?, overlaps_range?
      eventable.ex                      # Eventable protocol — auto-convert consumer structs to Event
      resource.ex                       # Resource struct — @enforce_keys [:id, :title], tree helpers
      availability.ex                   # Availability windows — recurring + date overrides, per-resource
      booking_config.ex                 # Slot constraints — duration, buffer, capacity, notice, advance
      day_marker.ex                     # DayMarker struct — date annotations (holidays, closures, notices, seasons)
                                        #   Fields: id, label, start_date, end_date, description, icon, color, type, available, availability, extra
                                        #   Helpers: covers_date?, markers_for_date, group_by_date, effective_end_date, span_days

      # --- LiveComponent ---
      calendar_component.ex             # LiveComponent — manages state, dispatches views, handles all events
                                        #   Compile-time install check warning
                                        #   Visibility filtering (opt-in via min_visibility attr: :auto, integer, or nil)
                                        #   Today badge: pass today={nil} to disable, show_header={false} for archive mode
                                        #   Header: today_visible? computed from visible_range, show_today_button (:auto/true/false)
                                        #   Internal events: lc_navigate, lc_today, lc_view_change, lc_date_click,
                                        #   lc_time_click, lc_event_click, lc_more_click, lc_range_select,
                                        #   lc_event_drop, lc_event_resize, lc_container_resized
                                        #   Catch-all handler for unknown events (logs, never crashes)
                                        #   Defensive callback invocation with try/rescue

      # --- View Function Components (8 views) ---
      views/
        month_grid.ex                   # Month grid — multi-day events as compact spanning bars (h-3.5, text-[0.6rem]),
                                        #   slot assignment for consistent positions across days,
                                        #   single-day events via EventItem with compact=true (suppresses urgency/priority styling),
                                        #   day markers as inline labels next to day number with MarkerTicker for cycling,
                                        #   cell background tinting by marker type,
                                        #   today badge (bg-primary rounded-full w-5 h-5, disableable via today={nil}),
                                        #   week numbers, weekend toggle, +N more overflow,
                                        #   CSS uses border-base-content/N for dark-mode-safe contrast
        week_grid.ex                    # Week time grid — spanning all-day bars in header, timed events with
                                        #   overlap layout (side-by-side columns), now indicator, business hours,
                                        #   text color auto-inferred from bg color via Safe.infer_text_color
        day_view.ex                     # Day view — delegates to WeekGrid with single date
        n_day_view.ex                   # N-day view — delegates to WeekGrid with computed dates
        year_view.ex                    # Year view — 12 MiniCalendars in responsive grid
        agenda.ex                       # Agenda — chronological list grouped by date
        timeline.ex                     # Timeline — horizontal time axis, resource rows
        resource_view.ex                # Resource columns — resources as columns in vertical time grid

      # --- Shared Rendering Primitives ---
      components/
        header.ex                       # Toolbar — 3-column CSS grid layout (left/center/right), center always centered
                                        #   Left: today button (auto-hides when today is visible, configurable via show_today_button)
                                        #   Center: ‹ Title › with prev/next navigation arrows
                                        #   Right: view switcher buttons
                                        #   Supports: RTL, translations, toolbar_start/toolbar_end slots
        event_item.ex                   # Event element — status styling, urgency animations, priority indicators,
                                        #   badge/icon support, ARIA labels, auto text color inference
                                        #   Compact mode (month view): suppresses urgency rings, priority weight, border_color, priority dots
                                        #   Full mode (day/week): all visual features active
        event_popover.ex                # Event detail popover — fixed overlay with backdrop (bg-base-content/30),
                                        #   escape to close, click-away, ARIA dialog, close button with hover state,
                                        #   title, time, location, description, status badge, edit/delete actions,
                                        #   customizable via inner_block and actions slots,
                                        #   dispatches lc:ticker-pause event to pause MarkerTickers while open
        time_gutter.ex                  # Time labels column — configurable format, secondary timezone, CSS sanitization
        mini_calendar.ex                # Compact month — year view + sidebar picker, event dots

      # --- Utilities ---
      utils/
        date_helpers.ex                 # Date math — month_grid, week_dates, n_day_dates, visible_range (all views + catch-all),
                                        #   shift (all views + catch-all), group_events_by_date (defensive)
        time_slots.ex                   # Time slots — generation, bookable slots with cond-based status, positioning
        constraints.ex                  # Booking validation — full pipeline with timezone fallback in snap_datetime_to_slot
        overlap_layout.ex               # Overlap collision — side-by-side column positioning for overlapping events
        i18n.ex                         # Translations — day/month names, labels with interpolation, title/time/date formatting
        safe.ex                         # Defensive helpers — to_date, to_time, safe_call, sanitize_css_dimension,
                                        #   safe_filter_events, infer_text_color (daisyUI bg→text-content mapping)
        telemetry.ex                    # Performance measurement — emits :telemetry events and logs warnings
                                        #   when hot paths exceed configurable thresholds.
                                        #   - measure/3: wraps an operation in :telemetry.span, emits
                                        #     [:phoenix_live_calendar, :measure, :start/:stop/:exception]
                                        #   - measure_and_warn/3: measures + Logger.warning if threshold exceeded
                                        #   - profile_ingress/2: runs once per data update in CalendarComponent.update.
                                        #     Measures event count AND estimated memory (:erts_debug.size with
                                        #     sample-based extrapolation). Catches both "too many items" and
                                        #     "few but huge items" cases. Emits [:phoenix_live_calendar, :ingress].
                                        #   - should_measure?/1: gate for hot paths — returns false for <=100
                                        #     events (zero overhead for most users) unless perf_always_measure.
                                        #   - Instrumented: group_events_by_date (10ms), compute_week_slots (5ms),
                                        #     OverlapLayout.compute (5ms), filter_events_by_visibility (5ms)
                                        #
                                        #   Config:
                                        #     config :phoenix_live_calendar,
                                        #       perf_warnings: true,            # false to silence
                                        #       perf_always_measure: false,     # true to measure small datasets
                                        #       perf_thresholds: %{group_events: 20}  # override defaults (ms)

      # --- Optional Ecto Layer (guarded by Code.ensure_loaded?(Ecto)) ---
      store/
        event_store.ex                  # Behaviour — list_events/1, get_event/2, create_event/2, update_event/3, delete_event/2
        ecto/
          event_schema.ex               # Ecto schema — phoenix_live_calendar_events, changeset, to_event/1
          event_store_ecto.ex           # Default Ecto implementation — range/resource/calendar filtering
          migrations.ex                 # Versioned migrations (Oban pattern) — V1 with indexes
          repo_helper.ex                # Runtime repo resolution via Application.get_env

      # --- Optional PubSub ---
      pubsub.ex                         # Subscribe/broadcast with scoped topics

      # --- 0.3 additions ---
      theme.ex                          # Semantic color tokens (:primary… + config :color_tokens) -> class pairs
      heatmap.ex                        # Date=>number -> intensity DayMarkers (palettes, :fill/:dot, classes/2)
      widgets.ex                        # Compressed dashboard forms: next_events/week_strip/activity_grid/activity_month/mini_timeline
      layer.ex                          # Layer struct (legend chips; events tagged via Event.layer_id)
      utils/sizing.ex                   # Server-side rem estimation (parse_rem/label_rem) for tiers + label fit

  priv/
    static/
      assets/
        phoenix_live_calendar.js                # 9 JS hooks (see JS Hooks section)
        phoenix_live_calendar.css               # Optional CSS: urgency animations, drag states, prefers-reduced-motion

  test/                                 # ~37 test files (see mix test for the live count)
    mix/tasks/
      phoenix_live_calendar_install_test.exs
    phoenix_live_calendar_test.exs
    phoenix_live_calendar/
      calendar_component_test.exs
      event_test.exs
      resource_test.exs
      availability_test.exs
      booking_config_test.exs
      day_marker_test.exs
      pubsub_test.exs
      components/
        header_test.exs
        event_item_test.exs
        event_popover_test.exs
        mini_calendar_test.exs
        time_gutter_test.exs
      views/
        month_grid_test.exs
        week_grid_test.exs
        day_view_test.exs
        n_day_view_test.exs
        year_view_test.exs
        agenda_test.exs
        timeline_test.exs
        resource_view_test.exs
      utils/
        date_helpers_test.exs
        time_slots_test.exs
        overlap_layout_test.exs
        constraints_test.exs
        i18n_test.exs
        safe_test.exs
        telemetry_test.exs
      store/ecto/                         # fake-repo logic tests (no DB)
        event_schema_test.exs
        event_store_ecto_test.exs
        repo_helper_test.exs
        migrations_test.exs
```


## Core Design Decisions

### Data Model

**End times are EXCLUSIVE** — half-open interval `[start, end)`. Matches FullCalendar, Google Calendar, iCal RFC 5545.

**Event struct:**
- `@enforce_keys [:id, :start]`
- `visibility` (default: 20) — Controls which views show the event. Opt-in: set `min_visibility={:auto}` on CalendarComponent to enable per-view filtering. Thresholds: day=10, week=20, month=30, year=40. Uses multiples of 10 for granularity. Can also set `min_visibility={30}` for a fixed threshold across all views.
- Status types: `:confirmed | :tentative | :cancelled | :pending_approval | :no_show`
- Priority types: `:low | :normal | :high | :urgent`
- Urgency types: `:none | :attention | :warning | :critical`
- Visual fields: `icon`, `badge`, `border_color`, `color`, `text_color`, `class`
- All-day events use `Date` type. Timed events use `DateTime` or `NaiveDateTime`.
- Midnight boundary: events ending at exactly `~T[00:00:00]` do NOT appear on the next day.
- Grouping fields include `layer_id` (Layers feature) and the plural
  `resource_ids` (an event can target several timeline/resource rows).
- `Event.day_window/4` is the single per-day segment rule every time grid
  uses (midnight-crossers split; exact-midnight ends stay on their day).
- `color` accepts semantic token atoms and configured tokens (Theme).

**DayMarker struct (date annotations):**
- `@enforce_keys [:id, :label, :start_date]`
- Types: `:holiday | :closure | :notice | :label | :season | :custom`
- `available: false` marks dates as closed (cell gets red tint)
- Can carry `availability` overrides for reduced hours
- Styling fields (0.3): `color` (whole-cell tint, tokens resolve via Theme),
  `text_color`/`class` (label chip), `show_label: false` (tint only — the
  heatmap case). Shared style helpers live ON DayMarker:
  `custom_color/semantic_class/type_tint/chip_class/labeled/dot`
- Rendered in the MONTH grid (cell tint + corner chips w/ ticker), the
  WEEK/DAY/N-DAY headers (chips + column tints + heat dots), and the
  YEAR/mini calendars (cell tints + heat dots)

**Resource, Availability, BookingConfig** — see struct files for full field lists.

### Month Grid Rendering

Multi-day events use a **slot assignment algorithm**:
1. For each week, find all multi-day events active in that week
2. Assign each a slot index (greedy, sorted by start date then longest first)
3. In each day cell, render multi-day bars in slot order at the top
4. Multi-day bars are compact (`h-3.5 text-[0.6rem]`) with no margin on continuation days
5. Start day gets `rounded` class + left margin, end day gets `rounded` + right margin
6. Middle days have no rounding, no margin — creating a solid visual line
7. Single-day events render below via EventItem with `compact={true}` — urgency/priority styling suppressed

**Day number row:** Flex container with day number (w-5 h-5 circle) + inline marker labels. Today gets `bg-primary rounded-full`. Pass `today={nil}` to disable.

**MarkerTicker:** When a day has 2+ markers, they cycle one at a time with fade transitions (300ms, configurable interval default 3s). Pauses on hover and when EventPopover is open. Controlled via `marker_ticker` (boolean) and `marker_ticker_interval` (ms) attrs.

**Important Tailwind note:** Rounding and margin classes for multi-day bars must be complete static strings returned from a helper function (not dynamically concatenated) or Tailwind will purge them. Current approach uses `multiday_rounding_class(is_start, is_end)` returning complete strings like `"rounded-l ml-1"`.

### Text Color Inference

`Safe.infer_text_color/1` maps daisyUI background classes to their content color:
- `"bg-warning"` → `"text-warning-content"`, `"bg-primary/80"` → `"text-primary-content"`, etc.
- Falls back to `"text-base-content"` for unknown patterns
- Used by MonthGrid (multi-day bars), WeekGrid (all-day bars), and EventItem

### Week/Day Grid Rendering

All-day events in week/day/N-day views render as spanning bars in the header row using CSS grid `grid-column: N / span M`. Multi-day all-day events stretch across day columns.

Timed events use the `OverlapLayout` algorithm for side-by-side column positioning when events overlap.

### Component Architecture

- **LiveComponent** (`CalendarComponent`) manages internal state (date, view mode)
- **Function components** for each view — composable, testable, usable standalone
- **Parent communicates via callback functions**
- **Catch-all `handle_event`** logs unknown events, never crashes
- **Callbacks wrapped in try/rescue** — broken consumer callbacks don't crash the calendar
- **Archive/read-only mode:** `date={~D[2024-03-15]}`, `today={nil}`, `show_header={false}`

### Header Layout

3-column CSS grid (`grid-cols-[1fr_auto_1fr]`) ensuring the center navigation is always perfectly centered regardless of left/right content:
- **Left:** Today button (auto-hides when today is in visible range) + `toolbar_start` slot
- **Center:** `‹ April 2026 ›` with prev/next arrows
- **Right:** View switcher + `toolbar_end` slot

`show_today_button`: `:auto` (default, hides when today visible) | `true` (always) | `false` (never)

### CSS Strategy

- **Target: Tailwind CSS / daisyUI.** Components use daisyUI semantic classes (bg-base-100, text-base-content, btn, badge, etc.). This is a deliberate choice — Phoenix 1.7+ ships Tailwind, 90%+ of Phoenix projects use it.
- **Dark mode contrast:** Uses `border-base-content/N` for borders (not `border-base-200/300`) to ensure visibility across all daisyUI themes, including those with minimal base-level contrast (e.g., phoenix-dark with only 3.65% lightness spread between base-100 and base-300). Opacity levels: container border `/15`, header divider `/15`, week rows `/8`, cell borders `/5`.
- **NOT framework-agnostic** at the CSS level, but `PhoenixLiveCalendar.Theme`
  (0.3) resolves semantic color TOKENS (`:primary`… + app-configured
  `config :phoenix_live_calendar, :color_tokens`) into class pairs — the
  data layer no longer hardcodes Tailwind strings. A full CSS theming/preset
  system beyond tokens remains rejected as over-engineering.
- **Non-Tailwind users can still use it** via the `class` override attribute on every component element.
- **TODO (docs phase):** Document all `cal-*` CSS classes used, which daisyUI/Tailwind classes they map to.
- **`@source` directive required** in consumer's app.css — added by `mix phoenix_live_calendar.install`
- CSS dimension values (slot_height, slot_width, resource_width) sanitized via `Safe.sanitize_css_dimension/2`

### EventItem Compact Mode

When rendered with `compact={true}` (used in month view), EventItem suppresses:
- Urgency classes (ring, animations) — prevents size differences
- Priority classes (font-weight changes) — prevents size differences
- Border color (border-l-4) — prevents width changes
- Priority dot indicator — invisible at compact size

All events in month view are the same physical size, differentiated only by background color.

### Defensive Error Handling

- All event handlers have catch-all clauses — unknown events logged, never crash
- Callbacks wrapped in try/rescue — broken consumer callbacks logged, not re-raised
- `group_events_by_date` filters invalid events (nil id/start) with logging
- `slot_status` wrapped in rescue — returns `:unavailable` on error
- `Safe` module: `safe_call/2`, `to_date/1`, `to_time/1`, `sanitize_css_dimension/2`, `safe_filter_events/1`, `infer_text_color/1`
- `snap_datetime_to_slot` falls back to UTC if timezone database unavailable
- Event `on_date?` handles midnight boundary correctly
- `today={nil}` is nil-safe throughout — no badge, no cell tint, no crash


## Visual Features

### Status-Based Styling (EventItem, suppressed in compact mode)

| Status | Visual Treatment |
|--------|-----------------|
| `:confirmed` | Solid background (default) |
| `:tentative` | Dashed border, 70% opacity |
| `:cancelled` | 50% opacity, strikethrough title |
| `:pending_approval` | Pulsing animation |
| `:no_show` | Red tint, strikethrough |

### Urgency Indicators (suppressed in compact/month view)

| Urgency | Visual Treatment |
|---------|-----------------|
| `:none` | No indicator (default) |
| `:attention` | Pulsing ring (info color) |
| `:warning` | Amber animated ring shadow (2s cycle) |
| `:critical` | Red animated ring shadow (1s cycle) |

### Priority (suppressed in compact/month view)

| Priority | Visual Treatment |
|----------|-----------------|
| `:low` | 80% opacity |
| `:normal` | Default |
| `:high` | Semibold text, warning dot |
| `:urgent` | Bold text, error dot |

### Day Markers

Day markers annotate dates, not time slots. They are NOT events.
- Rendered as inline labels next to day number (in the day number row)
- When 2+ markers on one day, MarkerTicker JS hook cycles through them with fade transitions
- Cell background tinted by type: holiday=red, closure=red, notice=blue, season=accent
- `available: false` markers add `cal-day-holiday` or `cal-day-closed` class
- Hover tooltip shows description

### Multi-Day Events (Month View)

- Compact bars (`h-3.5 text-[0.6rem]`) stretching edge-to-edge across day cells
- `rounded` + margin on start/end days, flat on continuation days
- Title shown only on start day; continuation days show solid color bar
- Text color auto-inferred from bg color via `Safe.infer_text_color/1`
- Single-day events rendered below via EventItem with `compact={true}`

### Event Popover

Fixed overlay modal with semi-transparent backdrop (`bg-base-content/30`).
- Escape key to close, click backdrop to close
- ARIA: `role="dialog"`, `aria-modal="true"`, `aria-labelledby`
- Close button with proper hover state and cursor
- Dispatches `lc:ticker-pause` custom event to pause all MarkerTickers while open
- Content: title, time, location, description, status badge, edit/delete actions
- Customizable via `inner_block` and `actions` slots

### Overlap Layout

`OverlapLayout.compute/1` assigns side-by-side columns for overlapping timed events.


## CalendarComponent Attrs

### Key configuration attrs

| Attr | Default | Description |
|------|---------|-------------|
| `date` | nil | Anchor date. Initial value **and** controlled override: seeds the view on mount and re-syncs only when the parent actually changes it — a re-render passing the same value preserves the user's own month navigation (see "View/date sync" below). |
| `today` | `Date.utc_today()` | Today's date for highlighting. `:none` disables all today decorations (archive views); `nil` = server today. |
| `view` | `:month` | Initial view mode. Same initial-plus-controlled semantics as `date`. |
| `views` | `[:month, :week, :day]` | Available view modes in switcher |
| `show_header` | `true` | Show/hide the header toolbar |
| `show_today_button` | `:auto` | `:auto` hides when today visible, `true` always, `false` never |
| `min_visibility` | `nil` | Visibility filtering: `nil` (off), `:auto` (per-view), or integer |
| `marker_ticker` | `true` | Enable/disable marker cycling animation |
| `marker_ticker_interval` | `3000` | Milliseconds between marker transitions |
| `enable_hooks` | `false` | Attach JS hooks to container for drag interactions |
| `now` | `Time.utc_now()` | Wall-clock for the now indicators (pass viewer-local with a tz-correct `today`) |
| `events_mode` | `:full` | `:window` trims events to the visible range (pair with `on_date_range_change`) |
| `layers` / `show_legend` | `[]` / `true` | Layer structs -> legend toggle chips; hidden layers filtered server-side |
| `header_layout` | `:auto` | Toolbar collapses to a start row when both wings are empty; `:centered`/`:start` force |
| `event_content` | `:auto` | Week/day/resource block content tier by estimated height (`:detail`/`:inline`/`:title`/`:none` force) |
| `min_event_height` | `"1.25rem"` | Height floor for week/day/resource blocks (`"0"` disables) |
| `label_position` (+`label_fit_ratio`, `label_fit_fallback`) | `:fit` | Timeline bar labels: inside when the estimate fits, else outside/suppressed |
| `show_time_axis` | `true` | Timeline hour header |
| `day_markers` | `[]` | DayMarkers render in month, week/day headers AND year/mini |

Slot forwarding: the views' customization slots (`:event`, `:day_cell`,
`:time_label`, `:resource_label`, `:resource_header`, `:day_header`,
`:no_events`) pass through `<.live_component>` children into every view
that supports them; `:info` feeds the toolbar's ⓘ disclosure.

### View/date sync (controlled vs uncontrolled)

`:view` and `:date` are **initial-plus-controlled**, not "reset on every render."
`update/2` tracks the last parent-provided value (`last_view_prop` / `last_date_prop`)
and only writes `internal_view` / `internal_date` when the incoming prop **differs**
from what the parent last sent. So:

- **Uncontrolled (common):** pass `view` / `date` once for the starting position
  and let the user navigate — routine parent re-renders (PubSub reloads, sibling
  assign changes) that re-pass the same value will **not** clobber their navigation.
- **Controlled:** change the `view` / `date` assign and the component follows.
- The component's own nav events (`lc_navigate` / `lc_today` / `lc_view_change`)
  update `internal_*` directly; they don't touch `last_*_prop`.

(Edge case: a parent can't force a re-sync to a value equal to the one it last sent —
change the value, or remount via a new `id`. This is the standard controlled-input
tradeoff and is what keeps user navigation from being discarded.)

## CalendarComponent Events

| Event | Params | Source |
|-------|--------|--------|
| `lc_navigate` | `%{direction: "prev"\|"next"}` | Header arrows |
| `lc_today` | none | Header today button |
| `lc_view_change` | `%{view: "month"\|"week"\|...}` | View switcher |
| `lc_date_click` | `%{date: "2026-04-01"}` | Date cell click |
| `lc_time_click` | `%{date, time, resource-id}` | Time slot click |
| `lc_event_click` | `%{event-id: "..."}` | Event click |
| `lc_more_click` | `%{date: "2026-04-01"}` | "+N more" link |
| `lc_range_select` | `%{date, start_time, end_time}` | JS: drag-to-select |
| `lc_event_drop` | `%{event_id, new_date, new_time, resource_id}` | JS: drag-to-move |
| `lc_event_resize` | `%{event_id, edge, new_time}` | JS: resize |
| `lc_container_resized` | `%{width: integer}` | JS: ResponsiveContainer |
| `lc_layer_toggle` | `%{layer: id-string}` | Legend chip click |

## Callbacks (Parent → Component)

| Callback | Payload |
|----------|---------|
| `on_date_select` | `Date.t()` |
| `on_time_select` | `%{date, time, datetime, resource_id}` |
| `on_event_click` | `event_id` |
| `on_more_click` | `Date.t()` |
| `on_range_select` | `%{date, start_time, end_time}` |
| `on_event_drop` | `%{event_id, new_date, new_time, resource_id}` |
| `on_event_resize` | `%{event_id, edge, new_time}` |
| `on_container_resized` | `%{width}` |
| `on_view_change` | `%{view, date}` |
| `on_date_range_change` | `%{start, end, view, date}` |
| `on_layers_change` | `%{visible: ids, hidden: ids}` |


## JS Hooks

File: `priv/static/assets/phoenix_live_calendar.js`
Packaged as `window.PhoenixLiveCalendarHooks`

| Hook | Purpose |
|------|---------|
| `PopoverPause` | Pauses all MarkerTickers while popover is open (mount→pause, destroy→resume) |
| `MarkerTicker` | Cycles day marker labels one at a time with fade transitions. Pauses on hover and on `lc:ticker-pause` event |
| `TimeRangeSelect` | Drag to select time range |
| `EventDrag` | Drag to move event (5px deadzone, ghost element) |
| `EventResize` | Drag edge to resize duration |
| `ResponsiveContainer` | ResizeObserver, 150ms debounce |
| `TouchHandler` | Long-press for mobile (500ms) |
| `PhoenixLiveCalendarContainer` | Composite — initializes TimeRangeSelect, EventDrag, EventResize, ResponsiveContainer, TouchHandler |
| `SyncAnimations` | Re-anchors CSS animations to one document-timeline origin on mount + subtree changes (MutationObserver/ResizeObserver + per-cell background offsets) so per-cell animations stay in phase across LiveView patches |


## PhoenixKit Demo Page

A full demo page is integrated into PhoenixKit admin at `/admin/calendar-demo`.

Files:
- `phoenix_kit/lib/phoenix_kit_web/live/calendar_demo.ex` — LiveView with demo data generators
- `phoenix_kit/lib/phoenix_kit_web/live/calendar_demo.html.heex` — Template with 5 demo sections
- `phoenix_kit/lib/modules/calendar_demo/calendar_demo.ex` — Module definition
- `phoenix_kit/lib/phoenix_kit/dashboard/admin_tabs.ex` — Tab registration (priority 650)
- `phoenix_kit/lib/phoenix_kit_web/integration.ex` — Route: `live "/admin/calendar-demo"`

Demo sections: Full Calendar, Status & Priority, Resource Views, Mini Widgets, Booking Config

Demo uses: `min_visibility={:auto}`, events with visibility 10–40, real April 2026 day markers (Good Friday, Easter Monday, team offsite, payday, reduced hours, maintenance, spring season), month-spanning multi-day event.

App JS setup: `app/assets/js/app.js` imports `phoenix_live_calendar.js` at `../../../phoenix_live_calendar/priv/static/assets/phoenix_live_calendar.js` (path dependency through phoenix_kit).


## Known Remaining Work

### Must fix before release

1. ~~**Multi-day bar slot alignment**~~ — **FIXED.** `multiday_bars_for_day` now keeps `{:spacer, idx}` placeholders for empty leading/interior slots (dropping only trailing ones) and the month template renders them as empty `cal-multiday-spacer` divs (`h-3.5`), so a multi-day bar keeps the same vertical row across every day it spans. Regression tests in `month_grid_test.exs` ("multi-day event slot alignment").

2. ~~**Install task needs JS integration**~~ — **FIXED.** `mix phoenix_live_calendar.install` now finds `app.js`, adds the hook import, and spreads `...window.PhoenixLiveCalendarHooks` into a single `hooks: { … }` literal (falling back to printed instructions otherwise). `--js-path` override added; idempotent via the `// PhoenixLiveCalendar JS hooks` marker.

3. **Week view vs month view spanning consistency** *(deferred — not a visible bug)* — Week all-day bars use CSS `grid-column: N / span M`; month uses per-cell slot bars. Both render correctly; this is an internal-consistency refactor (unify week onto the more-wrap-robust per-cell approach), not a broken behavior. Best done during the projects integration where it can be browser-verified, since rewriting a working component carries regression risk. (A separate latent issue worth checking then: overlapping multi-day all-day events in week view share one implicit grid row and can visually collide.)

### Should do before release

4. **Arrow key grid navigation** — WCAG keyboard navigation within the calendar grid (arrow keys between cells, Page Up/Down for months, Home/End for week boundaries) is not implemented. Requires a JS hook to intercept keyboard events and manage roving tabindex.

5. **Focus management** — Focus restoration after LiveView re-renders and view changes is not implemented. When the user navigates months or switches views, focus drops to `<body>`. Need to save focused cell and restore after patch.

6. ~~**CalendarComponent integration tests**~~ — SHIPPED: `calendar_component_test.exs` drives mount/update/handle_event directly and renders every view (no test endpoint needed).

7. ~~**Ecto integration tests**~~ — MOSTLY SHIPPED: the Ecto layer is covered via a fake repo (schema/store/repo_helper); only the migration DDL stays untested by design (the optional dep must not force Postgres on the suite).

8. **`prefers-reduced-motion`** — CSS is in the optional `phoenix_live_calendar.css` file but not in any auto-included styles. Consumer must manually import it. Should document this more prominently or include it inline.

### Nice to have

9. **Event overlap layout in resource view** — `OverlapLayout` is used in week/day/N-day views but not resource_view (same-time events in one column stack). The timeline is horizontal (bars overlap by design; labels resolve collisions).

10. **Print styles** — No CSS for printing calendar views.

11. **Recurring event visual indicator** — No built-in icon/badge for recurring event instances.

### Known gotchas to document

12. **Tailwind class purging** — Dynamic class concatenation in HEEx templates gets purged by Tailwind. All conditional Tailwind classes must be returned as complete static strings from helper functions (see `multiday_rounding_class` pattern in `month_grid.ex`). This applies to any new conditional classes added in the future.

13. **`@source` in parent app** — The `@source "../../deps/phoenix_live_calendar"` directive in `/www/app/assets/css/app.css` was manually added during development. If the app's CSS is regenerated or the install is re-run, this line exists. The `mix phoenix_live_calendar.install` task handles new installs, but existing manual entries should be preserved.

14. **Compile-time install check** — The warning in `calendar_component.ex` uses `IO.warn` at compile time, which fires during `mix compile` of ANY project that depends on phoenix_live_calendar. The package itself suppresses it via `config :phoenix_live_calendar, skip_install_check: true` in `config/config.exs`. Consumer projects that haven't run `mix phoenix_live_calendar.install` will see the warning on every compile until they install or suppress.

15. **Dark mode theme contrast** — The `phoenix-dark` daisyUI theme has only 3.65% lightness spread between base-100/200/300. Using `border-base-200` or `border-base-300` is nearly invisible. Always use `border-base-content/N` for borders.


## Commit Message Rules

Start with action verbs: `Add`, `Update`, `Fix`, `Remove`.

## Testing

- **405 tests, 0 failures** (82% line coverage; core ~90%+)
- Unit tests for all structs, utilities, constraints
- Component rendering tests for all views and primitives (using `rendered_to_string`)
- CalendarComponent: mount/update sync, every `handle_event/3` clause + callback, and `render/1` per view — driven directly (no endpoint needed)
- Ecto store layer: changeset/mapping + CRUD/delegation tested against a fake repo (no DB)
- Install Mix task: CSS/JS integration tested against temp-dir fixtures
- Defensive error handling tests (Safe module)
- PubSub topic generation tests
- Visibility tier tests (Event.visible_at?/2)
- **Not covered (documented residual):** the Ecto migration DDL (`Migrations` up/down — needs a real Postgres migrator), kept out of the default suite so the optional dep never forces a database on contributors

## Naming

The current name `phoenix_live_calendar` may be too narrow given the planned scope (timelines, resource scheduling, etc.). Consider renaming to something more generic in the future:

- **`live_timekit`** — preferred alternative. Clearly a toolkit for time-based UIs, covers calendars, timelines, scheduling, and booking without being too abstract.
