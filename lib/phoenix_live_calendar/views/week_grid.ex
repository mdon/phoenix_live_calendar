defmodule PhoenixLiveCalendar.Views.WeekGrid do
  @moduledoc """
  Week time grid view — 7 day columns with a vertical time axis.

  Also used as the base for day view (1 column) and N-day view (N columns).
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Components.{EventItem, TimeGutter}
  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils.{DateHelpers, I18n, OverlapLayout, Safe, Sizing, TimeSlots}

  @doc """
  Renders a week/day/N-day time grid.

  ## Attributes

  - `dates` — List of dates to display as columns
  - `id` — optional per-instance prefix for event DOM ids
  - `events` — List of `PhoenixLiveCalendar.Event` structs
  - `selected_date` — Currently selected date (tints its column)
  - `today` — Today's date
  - `now` — wall-clock time for the now indicator (default `Time.utc_now()`)
  - `min_time` — Earliest visible time (default: `~T[00:00:00]`)
  - `max_time` — Latest visible time (default: `~T[23:59:59]`)
  - `slot_duration` — Slot duration in minutes (default: 30)
  - `slot_height` — CSS height per slot (default: "3rem")
  - `show_now_indicator` — Show current time line (default: true)
  - `show_all_day_row` — Show all-day event row (default: true)
  - `day_markers` — `PhoenixLiveCalendar.DayMarker` structs: label chips
    under the day headers, column background tints (custom marker colors
    win over the type tints and the today tint)
  - `event_content` — `:auto` (default) picks per event block from its
    estimated height: `:detail` (title / start–end / location) ≥ 3.25rem,
    `:inline` (time + title) ≥ 1.75rem, `:title` ≥ 1.25rem, `:none` below
    (color only + tooltip — text never clips mid-glyph). Pass a specific
    tier to force it for every event
  - `min_event_height` — CSS floor for a block's rendered height (default
    `"1.25rem"`, one text line; `"0"` disables) — replaces the old 1.5%
    floor, which changed size with the visible window
  - `business_hours` — List of `PhoenixLiveCalendar.Availability` for highlighting
  - `on_date_click` — Handler for date header clicks
  - `on_time_click` — Handler for time slot clicks
  - `on_event_click` — Handler for event clicks
  - `translations` — Translation overrides
  - `time_format` — `:h24` or `:h12` (default: `:h24`)
  - `class` — Additional CSS classes
  - `dir` — Text direction (default: `:ltr`)

  ## Slots

  - `event` — Custom event rendering
  - `time_label` — Custom time gutter label
  """
  attr :dates, :list, required: true

  attr :id, :string,
    default: nil,
    doc:
      "Optional prefix for generated event DOM ids. Set it when two views on one page can render the SAME events — without it their per-event ids collide."

  attr :events, :list, default: []
  attr :selected_date, Date, default: nil
  attr :today, :any, default: nil, doc: "Date | nil (server today) | :none (no today highlight)"
  attr :min_time, Time, default: ~T[00:00:00]
  attr :max_time, Time, default: ~T[23:59:59]
  attr :slot_duration, :integer, default: 30
  attr :slot_height, :string, default: "3rem"
  attr :show_now_indicator, :boolean, default: true
  attr :show_all_day_row, :boolean, default: true

  attr :now, Time,
    default: nil,
    doc:
      "Current wall-clock time for the now indicator (default: `Time.utc_now()`). Pass the viewer's local time when your events/`today` are in the viewer's frame."

  attr :business_hours, :list, default: []
  attr :day_markers, :list, default: []

  attr :event_content, :atom,
    default: :auto,
    values: [:auto, :detail, :inline, :title, :none]

  attr :min_event_height, :string, default: "1.25rem"
  attr :on_date_click, :any, default: nil
  attr :on_time_click, :any, default: nil
  attr :on_event_click, :any, default: nil
  attr :translations, :map, default: %{}
  attr :time_format, :atom, default: :h24
  attr :class, :string, default: ""
  attr :dir, :atom, default: :ltr

  slot :event
  slot :time_label

  def week_grid(assigns) do
    today = DateHelpers.resolve_today(assigns.today)

    slots =
      TimeSlots.time_grid_slots(
        min_time: assigns.min_time,
        max_time: assigns.max_time,
        slot_duration: assigns.slot_duration
      )

    # Separate all-day and timed events
    {all_day_events, timed_events} =
      Enum.split_with(assigns.events, &Event.all_day?/1)

    # Group events by date
    events_by_date = DateHelpers.group_events_by_date(timed_events, assigns.dates)

    now = assigns.now || Time.utc_now()
    col_count = length(assigns.dates)

    # Estimated rem of block height per event minute — drives the content
    # ladder (server-side substitute for measuring the block).
    rem_per_minute = Sizing.parse_rem(assigns.slot_height, 3.0) / max(assigns.slot_duration, 1)

    markers_by_date =
      PhoenixLiveCalendar.DayMarker.group_by_date(assigns.day_markers, assigns.dates)

    # Compute overlap layout per day for side-by-side positioning
    overlap_layouts =
      Map.new(assigns.dates, fn date ->
        day_events = Map.get(events_by_date, date, [])
        {date, OverlapLayout.compute(day_events)}
      end)

    assigns =
      assigns
      |> assign(:today, today)
      |> assign(:slots, slots)
      |> assign(:events_by_date, events_by_date)
      |> assign(:all_day_events, all_day_events)
      |> assign(:overlap_layouts, overlap_layouts)
      |> assign(:now, now)
      |> assign(:col_count, col_count)
      |> assign(:markers_by_date, markers_by_date)
      |> assign(:rem_per_minute, rem_per_minute)
      |> assign(
        :now_in_window?,
        Time.compare(now, assigns.min_time) != :lt and
          Time.compare(now, assigns.max_time) != :gt
      )

    ~H"""
    <div class={["cal-week-grid flex flex-col", @class]} dir={to_string(@dir)}>
      <%!-- Day headers --%>
      <div class="cal-week-header flex border-b border-base-200">
        <div class="w-12 sm:w-16 flex-shrink-0"></div>
        <div class="flex-1 grid" style={"grid-template-columns: repeat(#{@col_count}, minmax(0, 1fr))"}>
          <div
            :for={date <- @dates}
            class={[
              "cal-day-column-header min-w-0 text-center py-1.5 sm:py-2 border-s border-base-200",
              date == @today && "bg-primary/5"
            ]}
          >
            <button
              :if={@on_date_click}
              type="button"
              class="hover:underline"
              phx-click={@on_date_click}
              phx-value-date={Date.to_iso8601(date)}
            >
              <.header_day_label date={date} today={@today} translations={@translations} />
            </button>
            <div :if={!@on_date_click}>
              <.header_day_label date={date} today={@today} translations={@translations} />
            </div>
            <%!-- Quiet heatmap variant: an intensity dot under the header --%>
            <% heat_dot = PhoenixLiveCalendar.DayMarker.dot(Map.get(@markers_by_date, date, [])) %>
            <div :if={heat_dot} class="flex justify-center pb-0.5">
              <span
                class={["cal-heat-dot w-1.5 h-1.5 rounded-full", heat_dot.class]}
                title={heat_dot.title}
                aria-hidden="true"
              >
              </span>
            </div>
            <%!-- Day marker chips: the zoomed views have header room for them --%>
            <div
              :if={PhoenixLiveCalendar.DayMarker.labeled(Map.get(@markers_by_date, date, [])) != []}
              class="flex flex-wrap justify-center gap-0.5 px-0.5 pb-0.5"
            >
              <span
                :for={
                  marker <- PhoenixLiveCalendar.DayMarker.labeled(Map.get(@markers_by_date, date, []))
                }
                class={[
                  "cal-marker-label max-w-full truncate text-[0.55rem] leading-none px-1 py-px rounded font-medium",
                  PhoenixLiveCalendar.DayMarker.chip_class(marker)
                ]}
                title={marker.description || marker.label}
              >
                <span :if={marker.icon} class="me-0.5">{marker.icon}</span>
                {marker.label}
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- All-day row with spanning bars --%>
      <div :if={@show_all_day_row and @dates != []} class="cal-all-day-row border-b border-base-200">
        <div class="flex">
          <div class="w-12 sm:w-16 flex-shrink-0 text-xs text-base-content/50 text-center py-1">
            {I18n.label(:all_day, @translations)}
          </div>
          <div class="flex-1 relative">
            <%!-- Grid background for cell borders --%>
            <div
              class="grid absolute inset-0"
              style={"grid-template-columns: repeat(#{@col_count}, minmax(0, 1fr))"}
            >
              <div :for={_date <- @dates} class="border-s border-base-200"></div>
            </div>
            <%!-- Spanning event bars --%>
            <div
              class="grid relative min-h-6 py-0.5"
              style={"grid-template-columns: repeat(#{@col_count}, minmax(0, 1fr))"}
            >
              <% week_start = hd(@dates)
              week_end = Date.add(List.last(@dates), 1)

              # Explicit lane per bar: grid auto-placement's sparse cursor
              # never reuses an earlier row, so overlapping bars stacked in
              # arrival order waste rows and can shuffle on update. Greedy
              # first-free-lane packing (sorted by start, longer first) is
              # deterministic and dense — the month grid's slot rule.
              lane_bars =
                @all_day_events
                |> Enum.filter(fn e -> Event.overlaps_range?(e, week_start, week_end) end)
                |> assign_allday_lanes() %>
              <div
                :for={{event, lane} <- lane_bars}
                class={[
                  "cal-spanning-bar rounded-sm px-1 py-0.5 text-xs font-medium truncate cursor-pointer mx-px mb-px",
                  PhoenixLiveCalendar.Theme.event_color_classes(event),
                  event.status == :cancelled && "opacity-50 line-through",
                  event.class
                ]}
                style={allday_bar_style(event, week_start, week_end, @col_count, lane)}
                phx-click={@on_event_click}
                phx-value-event-id={event.id}
                title={event.title}
              >
                <span :if={event.icon} class="me-0.5">{event.icon}</span>
                {event.title || "(No title)"}
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Time grid body --%>
      <div class="cal-week-body flex flex-1 overflow-y-auto">
        <TimeGutter.time_gutter
          slots={@slots}
          slot_height={@slot_height}
          time_format={@time_format}
        >
          <:time_label :let={time} :if={@time_label != []}>
            {render_slot(@time_label, time)}
          </:time_label>
        </TimeGutter.time_gutter>

        <div
          class="flex-1 grid relative"
          style={"grid-template-columns: repeat(#{@col_count}, minmax(0, 1fr))"}
        >
          <%!-- Day columns --%>
          <div
            :for={date <- @dates}
            class={[
              "cal-day-column min-w-0 border-s border-base-200 relative",
              day_column_classes(
                Map.get(@markers_by_date, date, []),
                date == @today,
                date == @selected_date
              )
            ]}
            data-date={Date.to_iso8601(date)}
          >
            <%!-- Slot grid lines --%>
            <div
              :for={slot <- @slots}
              class={[
                "cal-time-slot border-b border-base-200",
                slot_business_class(date, slot, @business_hours)
              ]}
              style={"height: #{Safe.sanitize_css_dimension(@slot_height)}"}
              phx-click={@on_time_click}
              phx-value-date={Date.to_iso8601(date)}
              phx-value-time={Time.to_iso8601(slot)}
              data-slot={Time.to_iso8601(slot)}
            >
            </div>

            <%!-- Positioned events with overlap layout --%>
            <div class="absolute inset-0 pointer-events-none">
              <% day_layout = Map.get(@overlap_layouts, date, %{}) %>
              <div
                :for={
                  {event, window} <-
                    day_segments(Map.get(@events_by_date, date, []), date, @min_time, @max_time)
                }
                class="absolute pointer-events-auto z-10"
                style={
                  event_position_style_with_overlap(
                    event,
                    window,
                    day_layout,
                    @min_time,
                    @max_time,
                    @min_event_height
                  )
                }
              >
                <%= if @event != [] do %>
                  {render_slot(@event, event)}
                <% else %>
                  <EventItem.event_item
                    event={event}
                    id_suffix={EventItem.instance_suffix(@id, Date.to_iso8601(date))}
                    on_click={@on_event_click}
                    time_format={@time_format}
                    content={event_tier(window, @event_content, @rem_per_minute)}
                    default_color="bg-primary/80"
                    class="h-full text-xs border-s-2 border-primary"
                  />
                <% end %>
              </div>
            </div>

            <%!-- Now indicator --%>
            <TimeGutter.now_indicator
              :if={@show_now_indicator && date == @today && @now_in_window?}
              current_time={@now}
              min_time={@min_time}
              max_time={@max_time}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  # -- Private helpers --

  attr :date, Date, required: true
  attr :today, :any, default: nil, doc: "Date | nil (server today) | :none (no today highlight)"
  attr :translations, :map, default: %{}

  # Narrow single-letter day names on phones, short names from `sm` up,
  # full name for screen readers — the month header's responsive pattern.
  defp header_day_label(assigns) do
    ~H"""
    <span
      class="text-xs text-base-content/60"
      aria-label={I18n.day_name(Date.day_of_week(@date), @translations)}
    >
      <span class="sm:hidden">{I18n.day_name_narrow(Date.day_of_week(@date), @translations)}</span>
      <span class="hidden sm:inline">
        {I18n.day_name_short(Date.day_of_week(@date), @translations)}
      </span>
    </span>
    <br />
    <span class={[
      "text-base sm:text-lg font-medium",
      @date == @today && "text-primary font-bold"
    ]}>
      {@date.day}
    </span>
    """
  end

  # Greedy first-free-lane packing over INCLUSIVE occupied dates (the same
  # overlap rule as the month grid's slots). Returns [{event, lane}].
  defp assign_allday_lanes(bars) do
    bars
    |> Enum.sort_by(fn e ->
      {Date.to_gregorian_days(Event.first_date(e)), -Event.duration_seconds(e)}
    end)
    |> Enum.reduce([], fn event, placed ->
      taken =
        placed
        |> Enum.filter(fn {other, _lane} -> Event.dates_overlap?(event, other) end)
        |> MapSet.new(fn {_other, lane} -> lane end)

      lane = Enum.find(Stream.iterate(0, &(&1 + 1)), &(not MapSet.member?(taken, &1)))
      [{event, lane} | placed]
    end)
    |> Enum.reverse()
  end

  # Column background precedence: custom marker color (heatmap) > type tint >
  # today tint > selected tint — stacking two bg-* utilities resolves by
  # stylesheet order, so exactly one is applied. The semantic hook class is
  # always kept.
  defp day_column_classes(markers, today?, selected?) do
    custom = PhoenixLiveCalendar.DayMarker.custom_color(markers)
    tint = PhoenixLiveCalendar.DayMarker.type_tint(markers)
    semantic = PhoenixLiveCalendar.DayMarker.semantic_class(markers)

    cond do
      custom -> ["cal-day-marked", semantic, custom]
      tint -> [semantic, tint]
      today? -> "bg-primary/5"
      selected? -> "bg-secondary/5"
      true -> nil
    end
  end

  # Each day's renderable {event, window} pairs, computed ONCE per event
  # (the segment used to be recomputed by the guard, the style and the tier).
  defp day_segments(events, date, min_time, max_time) do
    Enum.flat_map(events, fn event ->
      case Event.day_window(event, date, min_time, max_time) do
        nil -> []
        window -> [{event, window}]
      end
    end)
  end

  defp event_position_style_with_overlap(
         event,
         {start_time, end_time},
         layout_map,
         min_time,
         max_time,
         min_height
       ) do
    top = TimeSlots.time_to_percentage(start_time, min_time: min_time, max_time: max_time)
    bottom = TimeSlots.time_to_percentage(end_time, min_time: min_time, max_time: max_time)
    height = bottom - top

    # Get overlap positioning (column and total_columns)
    overlap_info = Map.get(layout_map, event.id, %{column: 0, total_columns: 1})
    h_style = OverlapLayout.position_style(overlap_info)

    # A rem floor (one text line by default) instead of the old 1.5% floor,
    # whose real size depended on the window; the top clamp keeps a floored
    # bottom-edge block inside the track.
    case height_floor(min_height) do
      nil ->
        "top: #{top}%; height: #{height}%; #{h_style}"

      floor ->
        "top: min(#{top}%, calc(100% - #{floor})); height: max(#{height}%, #{floor}); #{h_style}"
    end
  end

  defp height_floor(min_height), do: Safe.height_floor(min_height)

  # Content tier from the block's estimated height (whole text lines or
  # nothing — never a mid-glyph clip). Thresholds live in EventItem.
  defp event_tier({seg_start, seg_end}, :auto, rem_per_minute) do
    EventItem.tier_for_height(Time.diff(seg_end, seg_start) / 60 * rem_per_minute)
  end

  defp event_tier(_window, forced, _rpm), do: forced

  defp slot_business_class(_date, _slot_time, []), do: nil

  defp slot_business_class(date, slot_time, business_hours) do
    windows = PhoenixLiveCalendar.Availability.windows_for_date(business_hours, date)

    is_business =
      Enum.any?(windows, fn w ->
        w.available and PhoenixLiveCalendar.Availability.covers_time?(w, slot_time)
      end)

    unless is_business, do: "bg-base-200/30"
  end

  defp allday_bar_style(event, week_start, week_end, col_count, lane) do
    event_start = DateHelpers.to_date(event.start)
    event_end = DateHelpers.to_date(Event.effective_end(event))

    vis_start = if Date.compare(event_start, week_start) == :lt, do: week_start, else: event_start
    vis_end = if Date.compare(event_end, week_end) == :gt, do: week_end, else: event_end

    col_start = max(Date.diff(vis_start, week_start) + 1, 1)
    col_span = max(Date.diff(vis_end, vis_start), 1)
    col_span = min(col_span, col_count - col_start + 1)

    "grid-column: #{col_start} / span #{col_span}; grid-row: #{lane + 1}"
  end
end
