# AGENTS.md

**PhoenixLiveSchedule** — A comprehensive, server-rendered calendar and scheduling component library for Phoenix LiveView. Supports day, week, month, year, N-day, agenda, timeline, and resource views. Optional JS hooks for drag interactions, optional PubSub for real-time sync, optional Ecto for persistence. Zero JavaScript required for the base layer.


## Overview

PhoenixLiveSchedule is a standalone Hex package with no framework dependencies beyond Phoenix LiveView. It is designed to work with any Phoenix app, and optionally integrates with PhoenixKit via a separate bridge package.

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
phoenix_live_schedule (Hex, standalone)        <- anyone can use
    ^
phoenix_kit_calendar (bridge)          <- optional, PhoenixKit users only
    ^
phoenix_kit (existing)
```


## Installation

Consumer workflow:

```bash
# 1. Add to mix.exs
{:phoenix_live_schedule, "~> 0.1.0"}

# 2. Install
mix deps.get
mix phoenix_live_schedule.install
```

`mix phoenix_live_schedule.install` automatically:
- Finds `app.css` (checks `assets/css/app.css`, `priv/static/assets/app.css`, `assets/app.css`)
- Adds `@source "../../deps/phoenix_live_schedule";` after the last existing `@source` line
- Idempotent — safe to run multiple times
- Prints JS hook setup instructions
- Accepts `--css-path` override

**TODO:** The install task currently only handles CSS and prints JS as optional instructions. The JS hooks are now needed for the MarkerTicker and PopoverPause features (not just drag interactions). The install task should also:
- Find `app.js` and add the JS import line
- Add `...window.PhoenixLiveScheduleHooks` to the LiveSocket hooks config
- Or at minimum, make the printed instructions clearer that JS is recommended for full functionality

### JS Hook Setup (required for full functionality)

Add to `assets/js/app.js`:

```javascript
import "../../deps/phoenix_live_schedule/priv/static/assets/phoenix_live_schedule.js"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...window.PhoenixLiveScheduleHooks, ...Hooks }
})
```

Without this, the following features will not work:
- MarkerTicker (day marker cycling in month view)
- PopoverPause (ticker pauses when popover opens)
- Drag-to-select, drag-to-move, event resize
- ResponsiveContainer, TouchHandler

### Compile-time install check

If the consumer hasn't run `mix phoenix_live_schedule.install`, a compile-time warning is emitted:

```
warning: PhoenixLiveSchedule CSS integration not detected.
Run: mix phoenix_live_schedule.install
```

Suppress with: `config :phoenix_live_schedule, skip_install_check: true`

**This is critical** — without the `@source` directive, Tailwind purges all PhoenixLiveSchedule CSS classes and components render without any styling (no rounded corners, no colors, no layout).


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

**All layers implemented. 264 tests passing. Zero warnings. Zero credo strict issues.**

- 34 Elixir source files, 1 Mix task, 2 asset files (JS + CSS), 24 test files
- Layer 0 (Pure Elixir views): Complete — all 8 views
- Layer 1 (JS hooks): Complete — 8 hooks
- Layer 2 (PubSub): Complete
- Layer 3 (Booking constraints): Complete
- Layer 4 (Ecto): Complete
- Expert code review completed — all critical and major issues fixed
- PhoenixKit demo page created at `/admin/calendar-demo`
- Month view polish pass completed (visibility tiers, header redesign, color fixes, marker ticker, compact mode)


## Project Structure

```
phoenix_live_schedule/
  config/
    config.exs                          # skip_install_check: true for self-compilation

  lib/
    phoenix_live_schedule.ex                    # Main module — public API, installed?/0 check
    mix/
      tasks/
        phoenix_live_schedule.install.ex        # Mix task — adds @source to consumer's app.css

    phoenix_live_schedule/
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

      # --- View Function Components (9 views) ---
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
        waterfall.ex                    # Waterfall/Gantt — horizontal bars on date-range axis,
                                        #   zoom levels (day/week/month), today marker, progress fill,
                                        #   milestones (zero-duration diamonds), SVG connector arrows for deps,
                                        #   grouping via category/extra.group, assignee display,
                                        #   non-working day shading, uses standard Event struct.
                                        #
                                        #   Connector routing (orthogonal elbow paths):
                                        #   - Forward deps: east stem → bus-aware mid_x → east stem into target
                                        #     Same-source arrows share mid_x=x1+elbow (branch tree)
                                        #     Same-target arrows share mid_x=target_x-elbow (merge funnel)
                                        #   - Backward deps (target starts before source ends): east stem →
                                        #     south/north past source row border → west to target column →
                                        #     south/north to target row → east stem into target. Styled
                                        #     dashed red with red arrow marker. Flags scheduling conflicts
                                        #     that require "time travel" so planners can see them.
                                        #   - Coordinate system: everything in pixels against fixed
                                        #     content_width = total_days × day_px. SVG gets explicit
                                        #     width/height/viewBox matching the content area.
                                        #
                                        #   Row ordering (topological within groups):
                                        #   - Start-date sorted, BUT when an event is placed, its direct
                                        #     dependents whose other prerequisites are already placed get
                                        #     placed immediately after. Recursively chains.
                                        #   - Minimizes arrow crossings by putting connected events adjacent.
                                        #   - Manual override: set `extra.order` (integer) on any event to
                                        #     pin its position; unordered events use their computed
                                        #     placement index as the sort key.
                                        #
                                        #   Data mapping (all via standard Event struct):
                                        #   - title/start/end: task name and dates
                                        #   - color/status: styling
                                        #   - extra.progress_pct (0-100): progress fill
                                        #   - extra.group or category: group header + boundary
                                        #   - extra.assignee: shown in label
                                        #   - start == end: renders as milestone diamond
                                        #
                                        #   Connectors: list of connector maps passed separately.
                                        #   Shape (all optional except from/to):
                                        #     %{
                                        #       from: id, to: id,
                                        #       # --- semantics ---
                                        #       type: :fs | :ss | :ff | :sf,  # default :fs
                                        #       critical: boolean,              # default false
                                        #       label: String.t | nil,          # default nil
                                        #       label_orientation: :horizontal  # or :vertical
                                        #       # --- styling overrides (fall through to component defaults) ---
                                        #       color_class: "text-*",          # e.g. "text-success"
                                        #       stroke_width: number,           # e.g. 2.5
                                        #       opacity: 0..1,
                                        #       dasharray: "8 2" | "none",
                                        #       # --- routing overrides ---
                                        #       exit_stem: integer,             # source-side elbow px
                                        #       entry_stem: integer,            # target-side elbow px
                                        #       detour_side: :auto | :above | :below,
                                        #       bar_clearance: integer,         # min px from intermediate bars
                                        #       shape: :auto | :direct | :detour,
                                        #       avoid_collisions: boolean       # overrides component default
                                        #     }
                                        #
                                        #   Dependency types (standard Gantt semantics):
                                        #   - :fs finish-to-start   — A must finish before B can start
                                        #   - :ss start-to-start    — A must start   before B can start
                                        #   - :ff finish-to-finish  — A must finish  before B can finish
                                        #   - :sf start-to-finish   — A must start   before B can finish
                                        #
                                        #   Every arrow is the same 3-segment shape
                                        #   `M x1 y1 H mid V y2 H x2`. The type only changes
                                        #   which bar edges x1/x2 anchor to and which side of
                                        #   each bar the stems exit/enter. SVG `orient="auto"`
                                        #   auto-orients the arrowhead from the final segment.
                                        #   Only :fs produces a 5-segment backward detour when
                                        #   the schedule violates the constraint — :ss/:ff/:sf
                                        #   stay coherent because their stems exit the same
                                        #   side on both ends.
                                        #
                                        #   Bus routing: outgoing/incoming counts are keyed by
                                        #   {event_id, type}, so mixed-type arrows from one
                                        #   source don't collapse into a single (wrong) bus.
                                        #
                                        #   Bus stagger (forward fan-out / fan-in spreading):
                                        #   `bus_stagger_outgoing_px` and `bus_stagger_incoming_px`
                                        #   (component-level, default 0 = merged). When > 0,
                                        #   each arrow in a fan-out/fan-in bus gets its own trunk
                                        #   x offset by `lane * stagger_px` from the base position.
                                        #   Lane assignment is per-{event,side,direction} bus,
                                        #   sorted by other-end row position so adjacent rows
                                        #   produce adjacent lanes (visually monotonic comb).
                                        #   Per-task override via `extra.bus_stagger_outgoing_px`
                                        #   / `extra.bus_stagger_incoming_px`. When both source
                                        #   and target staggers apply, fan-out wins (matches
                                        #   choose_mid_x's existing precedence).
                                        #
                                        #   Bar-edge attach (where an arrow connects to the bar):
                                        #   `bus_attach_mode` chooses one of three strategies for
                                        #   the y-position on the bar's edge.
                                        #   - `:smart` (default) — for each side of each task, count
                                        #     outgoing arrows by direction. Majority going down →
                                        #     outgoing attaches to the bar's BOTTOM region (60% of
                                        #     bar height). Majority going up → outgoing at TOP
                                        #     (40%). Incoming gets the OPPOSITE region. Single
                                        #     direction on side → collapse to row center. Yields
                                        #     natural visual flow: typical downward arrows exit
                                        #     source bottom, enter target top.
                                        #   - `:type_zoned` — outgoing always at top, incoming
                                        #     always at bottom (regardless of direction). Uses
                                        #     `bus_split_offset_pct` (default 40 → 40/60 split).
                                        #   - `:center` — disable splits; everything centered.
                                        #   Per-task override via `extra.bus_attach_mode` on the
                                        #   Event. `bus_attach_inner_pct` (default 40) controls
                                        #   the smart-mode split offset.
                                        #
                                        #   Date sorting: `Enum.sort_by(events, &start, Date)`
                                        #   with the explicit `Date` sorter — without it, default
                                        #   term ordering compares `:day` key first, putting
                                        #   ~D[2026-07-05] BEFORE ~D[2026-05-14] (5 < 14).
                                        #
                                        #   Critical-first dependent placement: when a source has
                                        #   multiple direct dependents, `place_dependents/5` sorts
                                        #   them `{not critical?, gregorian_days}` so critical-path
                                        #   children land adjacent to the source. Date is the
                                        #   tiebreaker (gregorian-days int because Date in tuple
                                        #   keys re-triggers the sort gotcha above).
                                        #
                                        #   Critical flag renders stroke-primary + thicker
                                        #   stroke + `cal-wf-arrow-critical` marker. Invalid
                                        #   outranks critical (broken schedule stays red dashed).
                                        #
                                        #   Labels render as SVG <text> with stroke-base-100
                                        #   halo (paint-order=stroke), centered on path
                                        #   midpoint for forward paths, on the detour leg for
                                        #   backward. Ideal for "2d lag" / "parallel" / etc.
                                        #
                                        #   Multiple backward :fs arrows sharing (source,
                                        #   direction) get staggered lane offsets (2px per lane)
                                        #   on their detour_y so they don't draw on top of each
                                        #   other.
                                        #
                                        #   Every <path> and label <text> carries
                                        #   data-from-id / data-to-id / data-type /
                                        #   data-critical / data-invalid, enabling :has()-based
                                        #   hover highlighting in consumer CSS without any JS.
                                        #
                                        #   Bar-collision avoidance (attr: avoid_collisions,
                                        #   default true): computes a pixel obstacle map once
                                        #   per render and shifts the trunk x (forward) or the
                                        #   final vertical x (backward FS) to the nearest bar-
                                        #   edge candidate when it would pierce an unrelated
                                        #   intermediate-row bar. The shift is bounded by each
                                        #   dep type's valid range so arrow shapes don't break;
                                        #   if no clean x exists, falls back to preferred
                                        #   (crossing > broken shape). Disable on very large
                                        #   Gantts (O(connectors × bars)) or when you prefer
                                        #   strict bus alignment over obstacle avoidance.
                                        #
                                        #   Markers all use fill="currentColor" so a single
                                        #   text-* color class on the path drives both the line
                                        #   and its arrowhead. Path uses stroke-current, label
                                        #   text uses fill-current + stroke-base-100 halo.
                                        #   Works across every daisyUI theme (theme resolves
                                        #   text-primary / text-error / etc. per its palette).
                                        #
                                        #   Arrowhead geometry: marker viewBox 0 0 10 10 with
                                        #   refX=6 (path endpoint sits in the wider middle of the
                                        #   triangle, hides the stroke fully). Arrow tip extends
                                        #   ~2.4px past the path endpoint, so the non-milestone
                                        #   target gap is 4px (was 2 pre-fix) so the tip doesn't
                                        #   overlap the target bar. Milestone gap stays 10px.
                                        #
                                        #   Component-level defaults for every hardcoded class
                                        #   are exposed as attrs (connector_color_class,
                                        #   critical_stroke_width, bar_class, milestone_class,
                                        #   progress_complete_class, status_cancelled_class,
                                        #   today_marker_line_class, group_header_class, ...).
                                        #   Full list in the module's @doc. Per-connector fields
                                        #   override component defaults; component defaults
                                        #   override internal fallbacks. Structural
                                        #   cal-waterfall-* hook classes remain stable and are
                                        #   always rendered; consumer classes stack onto them.
                                        #
                                        #   Out-of-range filtering: `partition_events_by_range/2`
                                        #   drops events whose [start, end) doesn't overlap the
                                        #   visible date_range (no row, no bar, no obstacle, no
                                        #   connector references). Earlier/later counts are
                                        #   surfaced via the edge indicators.
                                        #
                                        #   Built-in toolbar (opt-in via `show_header={true}`):
                                        #   - Today button (default JS.dispatch lc:wf-scroll-today
                                        #     consumed by WaterfallAutoScroll hook; override with
                                        #     `on_scroll_today` for server-side handling)
                                        #   - Prev/next nav buttons (fire `on_navigate` callback
                                        #     with %{direction: "prev"|"next"} — consumer recomputes
                                        #     date_range)
                                        #   - Zoom switcher (fires `on_zoom_change` with the new
                                        #     atom; restrict to a subset via `zooms` attr)
                                        #   - `toolbar_start` / `toolbar_end` slots for consumer
                                        #     additions (e.g., a Reset button)
                                        #   - Independent toggles: `show_today_button`,
                                        #     `show_navigation`, `show_zoom_switcher`
                                        #
                                        #   Edge indicators: sticky pills at scroll edges, "← N
                                        #   earlier" / "N later →", showing counts of out-of-range
                                        #   events. Clickable when consumer wires
                                        #   `on_show_earlier` / `on_show_later`.
                                        #
                                        #   JS hook (opt-in via `enable_hooks={true}`):
                                        #   `WaterfallAutoScroll` centers today marker
                                        #   horizontally on mount (`auto_scroll_today={true}`,
                                        #   default) and on `lc:wf-scroll-today` custom event.
                                        #   Re-fires on LiveView updates so navigation/zoom changes
                                        #   re-center.

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
                                        #     [:phoenix_live_schedule, :measure, :start/:stop/:exception]
                                        #   - measure_and_warn/3: measures + Logger.warning if threshold exceeded
                                        #   - profile_ingress/2: runs once per data update in CalendarComponent.update.
                                        #     Measures event count AND estimated memory (:erts_debug.size with
                                        #     sample-based extrapolation). Catches both "too many items" and
                                        #     "few but huge items" cases. Emits [:phoenix_live_schedule, :ingress].
                                        #   - should_measure?/1: gate for hot paths — returns false for <=100
                                        #     events (zero overhead for most users) unless perf_always_measure.
                                        #   - Instrumented: group_events_by_date (10ms), compute_week_slots (5ms),
                                        #     OverlapLayout.compute (5ms), filter_events_by_visibility (5ms)
                                        #
                                        #   Config:
                                        #     config :phoenix_live_schedule,
                                        #       perf_warnings: true,            # false to silence
                                        #       perf_always_measure: false,     # true to measure small datasets
                                        #       perf_thresholds: %{group_events: 20}  # override defaults (ms)

      # --- Optional Ecto Layer (guarded by Code.ensure_loaded?(Ecto)) ---
      store/
        event_store.ex                  # Behaviour — list_events/1, get_event/2, create_event/2, update_event/3, delete_event/2
        ecto/
          event_schema.ex               # Ecto schema — phoenix_live_schedule_events, changeset, to_event/1
          event_store_ecto.ex           # Default Ecto implementation — range/resource/calendar filtering
          migrations.ex                 # Versioned migrations (Oban pattern) — V1 with indexes
          repo_helper.ex                # Runtime repo resolution via Application.get_env

      # --- Optional PubSub ---
      pubsub.ex                         # Subscribe/broadcast with scoped topics

  priv/
    static/
      assets/
        phoenix_live_schedule.js                # 8 JS hooks (see JS Hooks section)
        phoenix_live_schedule.css               # Optional CSS: urgency animations, drag states, prefers-reduced-motion

  test/                                 # 24 test files, 264 tests
    phoenix_live_schedule_test.exs
    phoenix_live_schedule/
      event_test.exs
      resource_test.exs
      availability_test.exs
      booking_config_test.exs
      pubsub_test.exs
      components/
        header_test.exs
        event_item_test.exs
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
        constraints_test.exs
        i18n_test.exs
        safe_test.exs
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

**DayMarker struct (date annotations):**
- `@enforce_keys [:id, :label, :start_date]`
- Types: `:holiday | :closure | :notice | :label | :season | :custom`
- `available: false` marks dates as closed (cell gets red tint)
- Can carry `availability` overrides for reduced hours
- Rendered as inline labels next to day number in month view (with ticker for cycling when multiple)

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
- **NOT framework-agnostic.** A theming/preset system was evaluated and rejected as over-engineering for the audience.
- **Non-Tailwind users can still use it** via the `class` override attribute on every component element.
- **TODO (docs phase):** Document all `cal-*` CSS classes used, which daisyUI/Tailwind classes they map to.
- **`@source` directive required** in consumer's app.css — added by `mix phoenix_live_schedule.install`
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
| `date` | nil | Anchor date for the view. If set, syncs internal date. |
| `today` | `Date.utc_today()` | Today's date for highlighting. Pass `nil` to disable. |
| `view` | `:month` | Initial view mode |
| `views` | `[:month, :week, :day]` | Available view modes in switcher |
| `show_header` | `true` | Show/hide the header toolbar |
| `show_today_button` | `:auto` | `:auto` hides when today visible, `true` always, `false` never |
| `min_visibility` | `nil` | Visibility filtering: `nil` (off), `:auto` (per-view), or integer |
| `marker_ticker` | `true` | Enable/disable marker cycling animation |
| `marker_ticker_interval` | `3000` | Milliseconds between marker transitions |
| `enable_hooks` | `false` | Attach JS hooks to container for drag interactions |

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


## JS Hooks

File: `priv/static/assets/phoenix_live_schedule.js`
Packaged as `window.PhoenixLiveScheduleHooks`

| Hook | Purpose |
|------|---------|
| `PopoverPause` | Pauses all MarkerTickers while popover is open (mount→pause, destroy→resume) |
| `MarkerTicker` | Cycles day marker labels one at a time with fade transitions. Pauses on hover and on `lc:ticker-pause` event |
| `TimeRangeSelect` | Drag to select time range |
| `EventDrag` | Drag to move event (5px deadzone, ghost element) |
| `EventResize` | Drag edge to resize duration |
| `ResponsiveContainer` | ResizeObserver, 150ms debounce |
| `TouchHandler` | Long-press for mobile (500ms) |
| `PhoenixLiveScheduleContainer` | Composite — initializes TimeRangeSelect, EventDrag, EventResize, ResponsiveContainer, TouchHandler |


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

App JS setup: `app/assets/js/app.js` imports `phoenix_live_schedule.js` at `../../../phoenix_live_schedule/priv/static/assets/phoenix_live_schedule.js` (path dependency through phoenix_kit).


## Known Remaining Work

### Must fix before release

1. **Multi-day bar slot alignment** — When day 1 has events A,B and day 2 has only B, event B may shift up on day 2 because spacer divs were removed for cleaner DOM. The slot assignment in `compute_week_slots` computes correct indices but `multiday_bars_for_day` filters out spacers. Need to re-add empty placeholder divs (same height, no color) to maintain visual alignment across days.

2. **Week view vs month view spanning inconsistency** — Week view uses CSS `grid-column: N / span M` for all-day spanning bars. Month view uses per-cell full-width bars with slot assignment. These two approaches should ideally be unified for consistency. The month view approach (per-cell) is more robust for wrapping.

3. **Install task needs JS integration** — Currently only handles CSS. Should also add JS import and hook registration to consumer's app.js, or at minimum make instructions clearer.

### Should do before release

4. **Arrow key grid navigation** — WCAG keyboard navigation within the calendar grid (arrow keys between cells, Page Up/Down for months, Home/End for week boundaries) is not implemented. Requires a JS hook to intercept keyboard events and manage roving tabindex.

5. **Focus management** — Focus restoration after LiveView re-renders and view changes is not implemented. When the user navigates months or switches views, focus drops to `<body>`. Need to save focused cell and restore after patch.

6. **CalendarComponent integration tests** — 0% test coverage. Needs `Phoenix.LiveViewTest` with a test endpoint and router to test the LiveComponent as a whole (event handlers, view switching, navigation).

7. **Ecto integration tests** — 0% test coverage on the Ecto layer (`EventSchema`, `EventStoreEcto`, `Migrations`, `RepoHelper`). Needs a test database with Ecto sandbox.

8. **`prefers-reduced-motion`** — CSS is in the optional `phoenix_live_schedule.css` file but not in any auto-included styles. Consumer must manually import it. Should document this more prominently or include it inline.

### Nice to have

**Per-connector `bus_attach_pos` override** — Currently the smart attach mode (`bus_attach_mode={:smart}`, default) decides each arrow's bar-edge attach y from the OTHER end's row position (out_up / out_down / in_above / in_below). Component-level (`bus_attach_mode`, `bus_attach_outer_pct`, `bus_attach_inner_pct`) and per-task (`extra.bus_attach_mode`) overrides exist. A natural extension would be a per-connector `:bus_attach_pos` field accepting `:top | :bottom | :center | :upper_middle | :lower_middle` (or a numeric `0..100` percentage) so a single arrow can be pinned to a specific position regardless of the smart rule. Useful when the consumer wants one specific connector to ride the bottom of a bar even though it'd normally smart-route to the top, e.g. to deliberately group it with a sibling. Skipped from Phase 1 to keep the override surface small; add when someone hits a concrete need.

**[Phase 2] Waterfall virtualized / windowed rendering** — Current Waterfall renders every in-range event's row + bar up-front. Fine for hundreds of events; breaks down past thousands. The goal is to scale to millions with bounded DOM and bounded per-render work. Aspirational — Phase 1 (built-in toolbar, auto-scroll-to-today, edge indicators, out-of-range filtering) already ships the UX affordances that make it unnecessary for typical projects. Design notes:

- **Not infinite scroll** — time is bidirectional (scroll both ways from wherever you are) and events span ranges (one that starts off-screen-left but ends on-screen must still render partially). It's a 2D windowing problem, not append-only pagination.
- **Data source** — reuse the existing `PhoenixLiveSchedule.Store.EventStore` behaviour: consumers implement `list_events/1` filtered by date range + resource, and pass that as a callback instead of the full `events` list. The component calls it with the current viewport range.
- **Scroll reporting** — new JS hook (`WaterfallViewportReporter`) throttled to ~100ms, pushes `{scroll_left, client_width}` to the LiveComponent, which maps to a date range and re-queries `list_events/1`.
- **Vertical virtualization** — orthogonal. Row-level: only render rows intersecting the vertical viewport. Harder than horizontal because row height is fixed (simpler math) but connector arrows cross unrendered rows. Probably use `LiveView.stream` for rows with `phx-viewport-top` / `phx-viewport-bottom` anchors.
- **Connector edge markers** — arrows that connect an on-screen event to an off-screen one render as short stems ending in an edge marker ("→ 3 deps out of view"). Click to navigate / extend range. Requires extending `compute_connector_paths` to handle one-sided paths.
- **Topo sort caveat** — current `auto_place_group` needs the full connector graph to minimize crossings. For millions of events this argues for loading event IDs + connectors cheaply up-front (just strings, no event structs) and lazy-loading the full `Event` data only for visible rows. Separate "layout pass" from "render pass."
- **Obstacle map** — `compute_bar_obstacles` is O(connectors × bars). At million-event scale this becomes the bottleneck even for connectors that don't need collision avoidance. Needs a spatial index (interval tree on row × date range) to query only bars in the arrow's y-span.
- **Wrap not rewrite** — the function component stays; wrap it in a LiveComponent `PhoenixLiveSchedule.Views.WaterfallLive` that owns the viewport state and calls the function component with a windowed events list. Consumers pick the wrapper or the raw function component based on scale.

9. **Event overlap layout in resource/timeline views** — `OverlapLayout` is used in week/day/N-day views but not in resource_view or timeline. Events in the same resource at the same time would stack rather than render side-by-side.

10. **Print styles** — No CSS for printing calendar views.

11. **Recurring event visual indicator** — No built-in icon/badge for recurring event instances.

12. **Percentage-based dependencies in Waterfall** — Extend connectors to anchor at a percentage of a bar's duration, not just `start`/`end`. Two primitives to support:

    a. **Partial-prerequisite start**: "B can start when A hits 30%". One connector, shifted source anchor — `%{from: a, to: b, from_pct: 30}`.
    b. **Split-progress gate**: "B runs to 50%, pauses, resumes when A finishes". B becomes a segmented bar with two deps — one nominal, one gated. `%{from: a, to: b, from_pct: 100, to_pct: 50}`.

    **Data model (recommended)**: collapse `type` into an anchor pair —
    ```elixir
    %{from: id, to: id, from_anchor: {:pct, 30}, to_anchor: {:start}}
    # :fs is sugar for {end, start}; :ss for {start, start}; etc.
    ```
    `endpoints_for/5` already computes pixel anchors per type; add a `{:pct, N}` case that does `start_px + (end_px - start_px) * N / 100`. Routing (3-seg / detour / collision / smart-placement) doesn't change — only the anchor x shifts.

    **Visual handling of mid-bar anchors** (pick one or offer as an attr):
    - Anchor markers on the bar (small tick at the pct point) — least disruptive, arrow still enters from the side.
    - Top/bottom emergence — arrow leaves/arrives from the bar's top edge at the pct x. Changes the shape family.
    - Bar segmenting — split the bar at the gate; arrow lands on the segment boundary. Most expressive, biggest refactor (affects `bar_geometry/3`, progress fill).

    **Interactions to think through**:
    - `extra.progress_pct` — if `progress_pct < from_pct`, the gate is unmet. Could render dashed/dimmed until threshold crossed.
    - Topo sort — current `auto_place_group` treats any `from→to` as "from strictly before to". Percent gates break that; need pct-aware topo.
    - `conflict?/2` — still `x2 < x1` but with shifted anchors. A pct arrow crossing back in time is still an invalid schedule.

    **Suggested phasing**:
    - Phase 1: `from_pct` / `to_pct` on connector + shifted endpoints + anchor markers on the bar. No bar splitting, no progress interaction.
    - Phase 2: progress-unmet styling when `from_event.progress_pct < from_pct`.
    - Phase 3: bar segmenting for split-progress gates — new `segments` field on Event, rework `bar_geometry`, multiple progress fills per segment.

### Known gotchas to document

12. **Tailwind class purging** — Dynamic class concatenation in HEEx templates gets purged by Tailwind. All conditional Tailwind classes must be returned as complete static strings from helper functions (see `multiday_rounding_class` pattern in `month_grid.ex`). This applies to any new conditional classes added in the future.

13. **`@source` in parent app** — The `@source "../../deps/phoenix_live_schedule"` directive in `/www/app/assets/css/app.css` was manually added during development. If the app's CSS is regenerated or the install is re-run, this line exists. The `mix phoenix_live_schedule.install` task handles new installs, but existing manual entries should be preserved.

14. **Compile-time install check** — The warning in `calendar_component.ex` uses `IO.warn` at compile time, which fires during `mix compile` of ANY project that depends on phoenix_live_schedule. The package itself suppresses it via `config :phoenix_live_schedule, skip_install_check: true` in `config/config.exs`. Consumer projects that haven't run `mix phoenix_live_schedule.install` will see the warning on every compile until they install or suppress.

15. **Dark mode theme contrast** — The `phoenix-dark` daisyUI theme has only 3.65% lightness spread between base-100/200/300. Using `border-base-200` or `border-base-300` is nearly invisible. Always use `border-base-content/N` for borders.


## Commit Message Rules

Start with action verbs: `Add`, `Update`, `Fix`, `Remove`.

## Testing

- **307 tests, 0 failures**
- Unit tests for all structs, utilities, constraints
- Component rendering tests for all views and primitives (using `rendered_to_string`)
- Defensive error handling tests (Safe module)
- PubSub topic generation tests
- Visibility tier tests (Event.visible_at?/2)
- **Not tested:** CalendarComponent LiveComponent (needs endpoint), Ecto layer (needs DB)

## Naming

The current name `phoenix_live_schedule` may be too narrow given the planned scope (timelines, resource scheduling, etc.). Consider renaming to something more generic in the future:

- **`live_timekit`** — preferred alternative. Clearly a toolkit for time-based UIs, covers calendars, timelines, scheduling, and booking without being too abstract.
