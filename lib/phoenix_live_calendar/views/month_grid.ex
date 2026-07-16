defmodule PhoenixLiveCalendar.Views.MonthGrid do
  @moduledoc """
  Month grid view — the traditional calendar layout with 6 rows of 7 days.

  Multi-day events render as full-width bars inside each day cell, occupying
  consistent slot positions across all days they span. This creates a visual
  continuous line without any absolute positioning — the grid handles sizing
  and wrapping naturally.

  Day markers (holidays, notices) tint the cell background with a corner label.
  A marker's own `color` class becomes the cell background (heatmap-style
  views send one marker per day with an intensity class); `text_color`/`class`
  style the corner chip; `show_label: false` renders the tint with no chip.
  Unset fields fall back to the type-based defaults.
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Components.EventItem
  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils.{DateHelpers, I18n, Telemetry}

  @doc """
  Renders a month grid — six rows of seven days.

  Multi-day events render as full-width bars that keep a consistent slot row
  across every day they span; day markers tint the matching cells.

  ## Attributes

  - `date` — any date within the month to render
  - `events` — list of `PhoenixLiveCalendar.Event` structs
  - `day_markers` — list of `PhoenixLiveCalendar.DayMarker` structs. A marker's
    `color`/`text_color`/`class`/`show_label` styling fields are honored (see
    `PhoenixLiveCalendar.DayMarker` — "Styling"); unset fields fall back to
    the type-based tints
  - `selected_date` / `today` — dates to highlight
  - `week_start` — `1` (Monday, default) … `7` (Sunday)
  - `max_events` — single-day events shown per cell before a "+N more" link (default `3`)
  - `max_multiday` — cap on multi-day bar rows per cell (default: no cap)
  - `expand_cells` — grow cells to fit all bars instead of clipping
  - `respect_hours` — position timed events by the hours they occupy (1h min width) instead of full-day
  - `show_week_numbers` / `show_weekends` / `fixed_weeks` — layout toggles
  - `on_date_click` / `on_event_click` / `on_more_click` — JS commands or event names
  - `translations` / `time_format` / `dir` / `class` — presentation
  """
  attr :date, Date, required: true

  attr :id, :string,
    default: nil,
    doc:
      "Optional prefix for generated DOM ids (marker tickers + per-event ids). Set it when two views on one page can render the same events/markers — without it their ids collide."

  attr :events, :list, default: []
  attr :day_markers, :list, default: []
  attr :selected_date, Date, default: nil
  attr :today, Date, default: nil
  attr :week_start, :integer, default: 1
  attr :max_events, :integer, default: 3

  attr :max_multiday, :integer,
    default: nil,
    doc:
      "Max multi-day bar rows to show per day cell; bars beyond it fold into the day's \"+N more\" link. `nil` (default) shows every bar (no cap)."

  attr :expand_cells, :boolean,
    default: false,
    doc:
      "When true, day cells grow vertically to fit all their bars (min-height, no clipping) instead of a fixed height that clips overflow. Useful when every event must stay visible (e.g. project bars)."

  attr :respect_hours, :boolean,
    default: false,
    doc:
      "When true, TIMED events cover only the fraction of a day they actually occupy: a single-day event becomes a bar offset by its start-time and sized to its duration, while a multi-day bar's boundary days trim to their start/end hours (middle days stay full). Very short events are floored to a 1-hour width so they stay visible. All-day events always cover full days (no hours). Off by default — bars span whole cells edge to edge and single-day events render as chips."

  attr :show_week_numbers, :boolean, default: false
  attr :show_weekends, :boolean, default: true
  attr :fixed_weeks, :boolean, default: true
  attr :on_date_click, :any, default: nil
  attr :on_event_click, :any, default: nil
  attr :on_more_click, :any, default: nil
  attr :translations, :map, default: %{}
  attr :time_format, :atom, default: :h24
  attr :marker_ticker, :boolean, default: true
  attr :marker_ticker_interval, :integer, default: 3000
  attr :class, :string, default: ""
  attr :dir, :atom, default: :ltr

  slot :day_cell
  slot :event

  def month_grid(assigns) do
    today = assigns.today || Date.utc_today()

    dates =
      DateHelpers.month_grid(assigns.date,
        week_start: assigns.week_start,
        fixed_weeks: assigns.fixed_weeks
      )

    dates =
      if assigns.show_weekends do
        dates
      else
        Enum.reject(dates, &DateHelpers.weekend?/1)
      end

    weeks = DateHelpers.group_by_weeks(dates)
    days_per_week = if assigns.show_weekends, do: 7, else: 5

    # Split events: anything occupying more than one calendar DATE renders as
    # one continuous bar (a multi-day all-day event, OR a timed event that
    # runs past midnight — a 10pm→2am event is on two dates); same-day events
    # render as per-day chips. Based on dates, not hours: the month view
    # doesn't care what time an event is, only which days it touches.
    {multi_day_events, other_events} =
      Enum.split_with(assigns.events, &Event.spans_multiple_dates?/1)

    # Group non-multi-day events by date (includes single-day all-day + timed)
    events_by_date = DateHelpers.group_events_by_date(other_events, dates)

    # Group markers by date
    markers_by_date = PhoenixLiveCalendar.DayMarker.group_by_date(assigns.day_markers, dates)

    # For each week, compute slot assignments for multi-day events
    # A slot is a row index that stays consistent across all days of the event
    week_slots =
      if Telemetry.should_measure?(length(multi_day_events)) do
        Telemetry.measure_and_warn(
          :slot_layout,
          %{multi_day_events: length(multi_day_events), weeks: length(weeks)},
          fn -> compute_all_week_slots(weeks, multi_day_events) end
        )
      else
        compute_all_week_slots(weeks, multi_day_events)
      end

    # Pair each short name with its single-letter narrow form (phones) and full
    # name (screen-reader label) so the header adapts without losing meaning:
    # "M T W…" on phones, "Mon Tue…" on wider screens, "Monday…" announced.
    short_names = I18n.ordered_day_names_short(assigns.week_start, assigns.translations)
    narrow_names = I18n.ordered_day_names_narrow(assigns.week_start, assigns.translations)
    full_names = I18n.ordered_day_names(assigns.week_start, assigns.translations)

    day_names =
      [short_names, narrow_names, full_names]
      |> Enum.zip()
      |> then(fn names ->
        if assigns.show_weekends,
          do: names,
          else: filter_weekday_names(names, assigns.week_start)
      end)

    assigns =
      assigns
      |> assign(:today, today)
      |> assign(:weeks, Enum.zip(weeks, week_slots))
      |> assign(:days_per_week, days_per_week)
      |> assign(:events_by_date, events_by_date)
      |> assign(:markers_by_date, markers_by_date)
      |> assign(:day_names, day_names)

    ~H"""
    <div class={["cal-month-grid", @class]} dir={to_string(@dir)}>
      <%!-- Day headers --%>
      <div
        class="cal-month-header grid border-b-2 border-base-content/15 bg-base-content/5"
        style={"grid-template-columns: #{if @show_week_numbers, do: "2rem ", else: ""}repeat(#{@days_per_week}, minmax(0, 1fr))"}
      >
        <div :if={@show_week_numbers} class="text-sm text-base-content text-center py-2">
          W
        </div>
        <div
          :for={{name, narrow, full} <- @day_names}
          class="cal-day-header text-xs sm:text-sm font-semibold text-base-content uppercase tracking-tight sm:tracking-wider py-1.5 sm:py-2 text-center"
          role="columnheader"
          aria-label={full}
        >
          <span class="sm:hidden">{narrow}</span>
          <span class="hidden sm:inline">{name}</span>
        </div>
      </div>

      <%!-- Week rows --%>
      <div
        :for={{week, slot_data} <- @weeks}
        class="cal-week-row grid border-b border-base-content/8"
        style={"grid-template-columns: #{if @show_week_numbers, do: "2rem ", else: ""}repeat(#{@days_per_week}, minmax(0, 1fr))"}
        role="row"
      >
        <%!-- Week number --%>
        <div
          :if={@show_week_numbers}
          class="cal-week-number text-sm text-base-content text-center pt-1 border-r border-base-content/10 row-span-1"
        >
          {elem(DateHelpers.week_number(hd(week)), 1)}
        </div>

        <%!-- Day cells --%>
        <div
          :for={day <- week}
          class={[
            "cal-day-cell min-w-0 border-r border-base-content/5 relative",
            if(@expand_cells,
              do: "min-h-24 md:min-h-28 lg:min-h-32",
              else: "min-h-24 h-24 md:h-28 lg:h-32 overflow-hidden"
            ),
            cell_classes(day, @date, @today, @selected_date, Map.get(@markers_by_date, day, []))
          ]}
          role="gridcell"
          aria-selected={to_string(day == @selected_date)}
          aria-current={if(day == @today, do: "date")}
          tabindex={if(day == (@selected_date || @today), do: "0", else: "-1")}
          phx-click={@on_date_click}
          phx-value-date={Date.to_iso8601(day)}
          data-date={Date.to_iso8601(day)}
        >
          <%= if @day_cell != [] do %>
            {render_slot(@day_cell, %{
              date: day,
              events: Map.get(@events_by_date, day, []),
              markers: Map.get(@markers_by_date, day, [])
            })}
          <% else %>
            <%!-- Day number row: number + marker labels --%>
            <div class="flex items-center gap-1 px-0.5 pt-0.5 min-h-5 overflow-hidden">
              <span class={[
                "cal-day-number text-xs sm:text-sm w-5 h-5 inline-flex items-center justify-center flex-shrink-0",
                day_number_class(day, @date, @today)
              ]}>
                {day.day}
              </span>
              <.marker_ticker
                id_prefix={@id}
                day={day}
                markers={labeled_markers(Map.get(@markers_by_date, day, []))}
                enabled={@marker_ticker}
                interval={@marker_ticker_interval}
              />
            </div>

            <%!-- Quiet heatmap variant: an intensity dot instead of the
                 whole-cell tint (Heatmap style: :dot) --%>
            <% dot = marker_dot(Map.get(@markers_by_date, day, [])) %>
            <div :if={dot}>
              <span
                class={[
                  "cal-heat-dot absolute bottom-1 inset-inline-start-1 w-1.5 h-1.5 rounded-full pointer-events-none",
                  dot.class
                ]}
                title={dot.title}
                aria-hidden="true"
              >
              </span>
            </div>

            <%!-- All events: multi-day first, then single-day. Multi-day bars
                 may be capped (@max_multiday); capped-off bars + single-day
                 overflow both feed the day's "+N more" link. --%>
            <% {multi_bars, multi_hidden} = multiday_bars_for_day(day, slot_data, @max_multiday)
            day_events = Map.get(@events_by_date, day, [])
            visible_single = Enum.take(day_events, @max_events)
            overflow = max(length(day_events) - @max_events, 0) + multi_hidden %>

            <%!-- Multi-day events: full width, edge to edge. Spacers hold empty
                 slots so each bar keeps the same vertical row across days. --%>
            <%= for entry <- multi_bars do %>
              <%= case entry do %>
                <% {:spacer, _idx} -> %>
                  <div class="cal-multiday-spacer h-3.5" aria-hidden="true"></div>
                <% {event, is_start, is_end} -> %>
                  <div
                    class={[
                      "cal-multiday-bar h-3.5 text-[0.6rem] leading-tight font-medium truncate cursor-pointer px-1 flex items-center",
                      event_bar_colors(event),
                      multiday_rounding_class(is_start, is_end),
                      event.status == :cancelled && "opacity-50 line-through",
                      event.class,
                      highlight_class(event, day)
                    ]}
                    phx-click={@on_event_click}
                    phx-value-event-id={event.id}
                    title={event.title}
                    style={bar_style(event, day, is_start, is_end, @respect_hours)}
                  >
                    <%!-- Label on the true start day AND at the start of each week
                         row, so a bar continuing from a previous week (or from
                         before the visible month) still shows its title. --%>
                    <%= if is_start or day == hd(week) do %>
                      <span :if={event.icon} class="mr-0.5">{event.icon}</span>
                      <span class="truncate">{event.title || "(No title)"}</span>
                    <% end %>
                  </div>
              <% end %>
            <% end %>

            <%!-- Single-day events. Normally full-width chips; in
                 respect_hours mode a TIMED event becomes a bar positioned by
                 its hours (min 1h wide). All-day events + a custom :event
                 slot are unaffected — no hours to respect. --%>
            <%= for event <- visible_single do %>
              <%= cond do %>
                <% @event != [] -> %>
                  <div class="mx-1 mt-px">{render_slot(@event, event)}</div>
                <% @respect_hours and not PhoenixLiveCalendar.Event.all_day?(event) -> %>
                  <% {gl, gw} = bar_geometry(event, true, true) %>
                  <div
                    id={"cal-event-#{event.id}-#{instance_suffix(@id, Date.to_iso8601(day))}"}
                    class={[
                      "cal-event cal-event-timed h-3.5 mt-px text-[0.6rem] leading-tight font-medium truncate cursor-pointer px-1 rounded flex items-center",
                      event_bar_colors(event),
                      event.status == :cancelled && "opacity-50 line-through",
                      event.class
                    ]}
                    style={"margin-left: #{pct(gl)}; width: #{pct(gw)}"}
                    phx-click={@on_event_click}
                    phx-value-event-id={event.id}
                    title={event.title}
                  >
                    <span :if={event.icon} class="mr-0.5">{event.icon}</span>
                    <span class="truncate">{event.title || "(No title)"}</span>
                  </div>
                <% true -> %>
                  <div class="mx-1 mt-px">
                    <EventItem.event_item
                      event={event}
                      id_suffix={instance_suffix(@id, Date.to_iso8601(day))}
                      on_click={@on_event_click}
                      compact={true}
                      time_format={@time_format}
                    />
                  </div>
              <% end %>
            <% end %>

            <button
              :if={overflow > 0}
              type="button"
              class="cal-more-link text-[0.6rem] text-base-content/60 hover:text-base-content mx-1"
              phx-click={@on_more_click}
              phx-value-date={Date.to_iso8601(day)}
            >
              {I18n.label(:more, @translations, %{count: overflow})}
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # -- Multi-day bars helper (returns flat list for inline rendering) --

  # Returns `{shown_entries, hidden_bar_count}`. With a `max` cap, only the first
  # `max` slot rows render; real bars (not spacers) pushed past it are counted so
  # the caller can surface them in the day's "+N more". `nil` = no cap.
  defp multiday_bars_for_day(day, slot_data, max) do
    if slot_data.slot_count == 0 do
      {[], 0}
    else
      {shown, hidden_count} =
        0..(slot_data.slot_count - 1)
        |> Enum.map(&slot_entry_for_day(&1, slot_data, day))
        |> cap_multiday(max)

      {drop_trailing_spacers(shown), hidden_count}
    end
  end

  defp cap_multiday(entries, max) when is_integer(max) and length(entries) > max do
    {shown, hidden} = Enum.split(entries, max)
    {shown, Enum.count(hidden, fn entry -> not match?({:spacer, _}, entry) end)}
  end

  defp cap_multiday(entries, _max), do: {entries, 0}

  # Each slot becomes either a rendered bar tuple or a {:spacer, idx} placeholder.
  # Spacers keep an event's vertical slot position identical across every day it
  # spans, so a multi-day bar reads as one continuous horizontal line instead of
  # shifting up on days where an earlier slot happens to be empty. A slot may
  # hold several non-overlapping events across the week, so pick the one active
  # on `day` (at most one, since same-slot events never overlap).
  defp slot_entry_for_day(idx, slot_data, day) do
    slot_data.slots
    |> Map.get(idx, [])
    |> Enum.find(&PhoenixLiveCalendar.Event.on_date?(&1, day))
    |> case do
      nil -> {:spacer, idx}
      event -> {event, event_start_date(event) == day, event_is_last_day?(event, day)}
    end
  end

  # Leading/interior spacers are kept for alignment; trailing spacers (slots after
  # this day's last real bar) are dropped so cells get no empty tail rows.
  defp drop_trailing_spacers(entries) do
    entries
    |> Enum.reverse()
    |> Enum.drop_while(&match?({:spacer, _}, &1))
    |> Enum.reverse()
  end

  # Per-day highlight: an event may carry `extra.highlight = %{from, to, class}`
  # to style only a sub-range of its multi-day bar (e.g. the overdue portion).
  # `class` is applied to day segments where `from <= day < to` (`from`/`to` are
  # optional; nil means open-ended on that side). The class string is the
  # consumer's responsibility to make Tailwind-visible.
  defp highlight_class(%{extra: %{highlight: %{class: class} = h}}, day) do
    if day_in_highlight?(day, h), do: class
  end

  defp highlight_class(_event, _day), do: nil

  # Exposes CSS custom properties on each in-range day of a `from`-anchored
  # highlight, so a consumer's CSS can drive per-day animations/gradients:
  #   * `--pk-hl-index` — 0-based offset from `from` (per-event)
  #   * `--pk-hl-day`   — the day's absolute date number (gregorian days), shared
  #                       across events, so a date-based animation stays in sync
  #                       across every highlighted bar (a wave that travels at one
  #                       speed regardless of each range's length)
  #   * `--pk-hl-count` — range length (only when the highlight has a bounded `to`)
  defp highlight_style(%{extra: %{highlight: %{from: %Date{} = from} = h}}, day) do
    if day_in_highlight?(day, h) do
      base = "--pk-hl-index: #{Date.diff(day, from)}; --pk-hl-day: #{Date.to_gregorian_days(day)}"

      case Map.get(h, :to) do
        %Date{} = to -> base <> "; --pk-hl-count: #{Date.diff(to, from)}"
        _ -> base
      end
    end
  end

  defp highlight_style(_event, _day), do: nil

  # Smallest fraction of a day a bar may occupy in respect_hours mode, so a
  # very short event (e.g. 5 minutes) stays visible/clickable. One hour.
  @min_bar_fraction 1.0 / 24.0

  # Combined inline style for a MULTI-DAY bar segment: the highlight
  # custom-properties plus, in respect_hours mode, a left offset + width so the
  # segment only covers the fraction of its boundary day the event occupies.
  defp bar_style(event, day, is_start, is_end, respect_hours) do
    [highlight_style(event, day), geometry_style(event, is_start, is_end, respect_hours)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("; ")
    |> case do
      "" -> nil
      style -> style
    end
  end

  # `margin-left` + `width` positioning a bar to its real hour-span. Off (or an
  # all-day event, which has no hours) → nil, so the bar stays full-width. The
  # inline margin-left overrides the fixed ml-1 cap margin.
  defp geometry_style(_event, _is_start, _is_end, false), do: nil

  defp geometry_style(%Event{start: %Date{}}, _is_start, _is_end, true), do: nil

  defp geometry_style(event, is_start, is_end, true) do
    {left, width} = bar_geometry(event, is_start, is_end)

    if left <= 0.0 and width >= 1.0 do
      # a full-width middle day — no need for inline geometry
      nil
    else
      "margin-left: #{pct(left)}; width: #{pct(width)}"
    end
  end

  # {left_fraction, width_fraction} for an event's bar on one day. A boundary
  # day is trimmed to the hours the event occupies; a middle day is full
  # (`{0.0, 1.0}`). A single-day event passes is_start=is_end=true. Width is
  # floored at @min_bar_fraction and nudged left to stay inside the cell.
  defp bar_geometry(event, is_start, is_end) do
    left = if is_start, do: start_day_fraction(event), else: 0.0
    right = if is_end, do: end_day_fraction(event), else: 1.0
    width = max(right - left, @min_bar_fraction)
    left = left |> min(1.0 - width) |> max(0.0)
    {left, width}
  end

  # Fraction of the day BEFORE the event begins (0 for an all-day event).
  defp start_day_fraction(%Event{start: %Date{}}), do: 0.0
  defp start_day_fraction(%Event{start: start}), do: day_fraction(start)

  # Fraction of the day the event covers UP TO its end. All-day and
  # exactly-midnight ends fill the day (1.0) — a midnight end means the last
  # occupied day is the previous, fully-covered one.
  defp end_day_fraction(%Event{} = event) do
    case Event.effective_end(event) do
      %Date{} ->
        1.0

      dt ->
        f = day_fraction(dt)
        if f == 0.0, do: 1.0, else: f
    end
  end

  defp day_fraction(dt) do
    t = time_of(dt)
    (t.hour * 3600 + t.minute * 60 + t.second) / 86_400
  end

  defp time_of(%DateTime{} = dt), do: DateTime.to_time(dt)
  defp time_of(%NaiveDateTime{} = dt), do: NaiveDateTime.to_time(dt)

  defp pct(fraction), do: "#{Float.round(fraction * 100, 2)}%"

  defp day_in_highlight?(day, h) do
    from = Map.get(h, :from)
    to = Map.get(h, :to)

    (is_nil(from) or Date.compare(day, from) != :lt) and
      (is_nil(to) or Date.compare(day, to) == :lt)
  end

  # Static strings for Tailwind purge safety — each return value is a
  # complete class string that the scanner can find in the source.
  defp multiday_rounding_class(true, true), do: "rounded ml-1 mr-1"
  defp multiday_rounding_class(true, false), do: "rounded-l ml-1"
  defp multiday_rounding_class(false, true), do: "rounded-r mr-1"
  defp multiday_rounding_class(false, false), do: nil

  # -- Day marker label (top-right corner) --

  attr :id_prefix, :string, required: true
  attr :day, Date, required: true
  attr :markers, :list, required: true
  attr :enabled, :boolean, required: true
  attr :interval, :integer, required: true

  defp marker_ticker(%{markers: []} = assigns) do
    ~H""
  end

  defp marker_ticker(%{markers: [_single]} = assigns) do
    # Single marker — no ticker needed, just show it
    ~H"""
    <span
      class={[
        "cal-marker-label text-[0.55rem] leading-none px-1 py-px rounded font-medium truncate",
        marker_chip_class(hd(@markers))
      ]}
      title={hd(@markers).description || hd(@markers).label}
    >
      <span :if={hd(@markers).icon} class="mr-0.5">{hd(@markers).icon}</span>
      {hd(@markers).label}
    </span>
    """
  end

  defp marker_ticker(%{enabled: false} = assigns) do
    # Ticker disabled — show first marker only
    ~H"""
    <span
      class={[
        "cal-marker-label text-[0.55rem] leading-none px-1 py-px rounded font-medium truncate",
        marker_chip_class(hd(@markers))
      ]}
      title={hd(@markers).description || hd(@markers).label}
    >
      <span :if={hd(@markers).icon} class="mr-0.5">{hd(@markers).icon}</span>
      {hd(@markers).label}
    </span>
    """
  end

  defp marker_ticker(assigns) do
    # Multiple markers with ticker enabled.
    # Uses a grid stack so all items occupy the same cell.
    # Only the first is visible; the JS hook cycles through them.
    # The id includes the day: a multi-day marker yields the identical marker
    # list on every day it covers, so a hash of the list alone would collide.
    # The optional grid-level id prefix disambiguates two grids on one page.
    ~H"""
    <div
      class="cal-marker-ticker grid min-w-0"
      phx-hook="MarkerTicker"
      data-interval={@interval}
      id={"#{if @id_prefix, do: "#{@id_prefix}-"}ticker-#{Date.to_iso8601(@day)}-#{:erlang.phash2(@markers)}"}
    >
      <span
        :for={{marker, idx} <- Enum.with_index(@markers)}
        class={[
          "col-start-1 row-start-1 cal-marker-label flex items-center text-[0.55rem] leading-none px-1 py-px rounded font-medium truncate transition-opacity duration-300",
          marker_chip_class(marker),
          if(idx == 0, do: "opacity-100", else: "opacity-0 pointer-events-none")
        ]}
        data-ticker-index={idx}
        title={marker.description || marker.label}
      >
        <span :if={marker.icon} class="mr-0.5 flex-shrink-0">{marker.icon}</span>
        <span class="truncate">{marker.label}</span>
      </span>
    </div>
    """
  end

  # Markers that want a corner label chip. `show_label: false` (or a nil
  # label) renders only the cell tint — the heatmap case.
  defp labeled_markers(markers), do: PhoenixLiveCalendar.DayMarker.labeled(markers)

  # A marker's own chip styling wins; type-based colors are the fallback.
  defp marker_chip_class(marker), do: PhoenixLiveCalendar.DayMarker.chip_class(marker)

  # -- Slot computation --
  # Assigns a consistent row index to each multi-day event across all days of the week

  defp compute_all_week_slots(weeks, multi_day_events) do
    Enum.map(weeks, fn week -> compute_week_slots(week, multi_day_events) end)
  end

  defp compute_week_slots(week, multi_day_events) do
    week_start = hd(week)
    week_end = Date.add(List.last(week), 1)

    # Events active this week, ordered by slot_priority (lets a consumer group
    # related bars into the top slots), then start, then longest first.
    active =
      multi_day_events
      |> Enum.filter(&Event.overlaps_range?(&1, week_start, week_end))
      |> Enum.sort_by(fn e ->
        {slot_priority(e), event_start_date(e), -Event.duration_seconds(e)}
      end)

    if active == [] do
      %{slot_count: 0, slots: %{}}
    else
      # Greedily assign slot indices
      {slots_map, slot_count} = Enum.reduce(active, {%{}, 0}, &assign_event_slot/2)

      # Convert to %{slot_index => [events]}. A slot can hold MORE than one event
      # per week — non-overlapping events legitimately share a row — so group
      # rather than collapse to one (which would drop all but the last).
      by_slot =
        slots_map
        |> Map.values()
        |> Enum.group_by(fn {_event, idx} -> idx end, fn {event, _idx} -> event end)

      %{slot_count: slot_count, slots: by_slot}
    end
  end

  # Optional per-event slot ordering hint (`extra.slot_priority`, integer): lower
  # values are packed into lower (top) slots, so a consumer can group related
  # bars together. Defaults to 0 (no preference).
  defp slot_priority(%{extra: %{slot_priority: p}}) when is_integer(p), do: p
  defp slot_priority(_event), do: 0

  # Greedily assign one event the first slot index not occupied by an
  # overlapping event already placed this week.
  defp assign_event_slot(event, {assignments, max_slot}) do
    used = occupied_slot_indices(assignments, event)

    slot_idx =
      Stream.iterate(0, &(&1 + 1))
      |> Enum.find(&(not MapSet.member?(used, &1)))

    {Map.put(assignments, event.id, {event, slot_idx}), max(max_slot, slot_idx + 1)}
  end

  defp occupied_slot_indices(assignments, event) do
    assignments
    |> Map.values()
    |> Enum.filter(fn {other_event, _slot_idx} -> events_overlap_dates?(event, other_event) end)
    |> Enum.map(fn {_event, slot_idx} -> slot_idx end)
    |> MapSet.new()
  end

  # -- Private helpers --

  defp instance_suffix(nil, key), do: key
  defp instance_suffix(id, key), do: "#{id}-#{key}"

  # A marker's own `color` owns the cell background: it replaces the
  # weekend/out-of-month tint AND the type-based marker tint (stacking two
  # bg-* utilities on one element resolves by stylesheet order, not class
  # order — nondeterministic). Today/selected switch from a bg tint to an
  # inset ring so they stay visible over any marker color (the heatmap
  # layering rule: marker color under the today/selected indicator, over
  # the weekend tint).
  defp cell_classes(day, month_date, today, selected, markers) do
    case marker_custom_color(markers) do
      nil -> plain_cell_classes(day, month_date, today, selected, markers)
      color -> marked_cell_classes(day, today, selected, color, markers)
    end
  end

  defp plain_cell_classes(day, month_date, today, selected, markers) do
    [
      not DateHelpers.in_month?(day, month_date) && "bg-base-content/[0.03]",
      day == today && "bg-primary/10",
      day == selected && day != today && "bg-secondary/10",
      DateHelpers.weekend?(day) && DateHelpers.in_month?(day, month_date) &&
        "bg-base-content/[0.02]",
      marker_bg_class(markers)
    ]
  end

  # The custom color replaces only the type-based bg UTILITY — the semantic
  # hook class (cal-day-holiday etc.) is kept so consumer CSS/tests keying
  # off it keep matching.
  defp marked_cell_classes(day, today, selected, color, markers) do
    [
      "cal-day-marked",
      marker_semantic_class(markers),
      color,
      day == today && "ring-2 ring-inset ring-primary",
      day == selected && day != today && "ring-2 ring-inset ring-secondary"
    ]
  end

  # First custom cell color among the day's markers, if any.
  defp marker_custom_color(markers), do: PhoenixLiveCalendar.DayMarker.custom_color(markers)

  # First :dot-style heatmap marker for the day, if any.
  defp marker_dot(markers) do
    Enum.find_value(markers, fn marker ->
      case marker.extra do
        %{heatmap: %{style: :dot, class: class}} -> %{class: class, title: marker.label}
        _ -> nil
      end
    end)
  end

  # Semantic hook class for the day's markers (no bg utility).
  defp marker_semantic_class(markers), do: PhoenixLiveCalendar.DayMarker.semantic_class(markers)

  defp marker_bg_class([]), do: nil

  defp marker_bg_class(markers) do
    case {marker_semantic_class(markers), PhoenixLiveCalendar.DayMarker.type_tint(markers)} do
      {nil, _} -> nil
      {semantic, tint} -> [semantic, tint]
    end
  end

  defp day_number_class(day, month_date, today) do
    cond do
      day == today ->
        "font-bold text-primary-content bg-primary rounded-full"

      DateHelpers.in_month?(day, month_date) ->
        "text-base-content"

      true ->
        "text-base-content/30"
    end
  end

  # One merge rule for bar colors: resolved token/string bg (default
  # bg-primary) + explicit text_color, else the token pair's text, else
  # inferred from the APPLIED background (the old code inferred from the raw
  # color, so a color-less bar got base-content text on a primary bg).
  defp event_bar_colors(event) do
    {bg, text} = PhoenixLiveCalendar.Theme.event_colors(event)
    [bg, text]
  end

  defp event_start_date(%Event{} = e) do
    case e.start do
      %Date{} = d -> d
      %DateTime{} = dt -> DateTime.to_date(dt)
      %NaiveDateTime{} = ndt -> NaiveDateTime.to_date(ndt)
    end
  end

  defp event_is_last_day?(event, day) do
    # Use the SAME last-occupied date as on_date?, or the two disagree: a
    # timed event ending after midnight on its last day occupies that day
    # (on_date? renders a bar segment there) but the old `end_date - 1`
    # exclusive rule marked the PREVIOUS day as the end — so the real last
    # day rendered as a stray, un-capped stub.
    Date.compare(PhoenixLiveCalendar.Event.last_date(event), day) == :eq
  end

  # Compare INCLUSIVE last dates (Event.last_date/1) — the same occupancy rule
  # on_date?/event_is_last_day? use. The old raw-end-date + strict :gt check
  # treated a midnight-crossing timed event (22:00 → 01:00 next day) as ending
  # a day early: it could share a slot with an event starting that next day,
  # and slot_entry_for_day's Enum.find then silently dropped one segment.
  defp events_overlap_dates?(a, b) do
    a_start = event_start_date(a)
    a_last = Event.last_date(a)
    b_start = event_start_date(b)
    b_last = Event.last_date(b)

    Date.compare(a_start, b_last) != :gt and Date.compare(a_last, b_start) != :lt
  end

  defp filter_weekday_names(names, week_start) do
    days = Enum.map(0..6, fn offset -> rem(week_start - 1 + offset, 7) + 1 end)

    Enum.zip(days, names)
    |> Enum.reject(fn {day, _} -> day in [6, 7] end)
    |> Enum.map(fn {_, name} -> name end)
  end
end
