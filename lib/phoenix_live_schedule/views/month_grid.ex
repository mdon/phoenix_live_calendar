defmodule PhoenixLiveSchedule.Views.MonthGrid do
  @moduledoc """
  Month grid view — the traditional calendar layout with 6 rows of 7 days.

  Multi-day events render as full-width bars inside each day cell, occupying
  consistent slot positions across all days they span. This creates a visual
  continuous line without any absolute positioning — the grid handles sizing
  and wrapping naturally.

  Day markers (holidays, notices) tint the cell background with a corner label.
  """

  use Phoenix.Component

  alias PhoenixLiveSchedule.Components.EventItem
  alias PhoenixLiveSchedule.Event
  alias PhoenixLiveSchedule.Utils.{DateHelpers, I18n, Safe, Telemetry}

  @doc """
  Renders a month grid — six rows of seven days.

  Multi-day events render as full-width bars that keep a consistent slot row
  across every day they span; day markers tint the matching cells.

  ## Attributes

  - `date` — any date within the month to render
  - `events` — list of `PhoenixLiveSchedule.Event` structs
  - `day_markers` — list of `PhoenixLiveSchedule.DayMarker` structs
  - `selected_date` / `today` — dates to highlight
  - `week_start` — `1` (Monday, default) … `7` (Sunday)
  - `max_events` — single-day events shown per cell before a "+N more" link (default `3`)
  - `max_multiday` — cap on multi-day bar rows per cell (default: no cap)
  - `expand_cells` — grow cells to fit all bars instead of clipping
  - `show_week_numbers` / `show_weekends` / `fixed_weeks` — layout toggles
  - `on_date_click` / `on_event_click` / `on_more_click` — JS commands or event names
  - `translations` / `time_format` / `dir` / `class` — presentation
  """
  attr :date, Date, required: true
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
    today = assigns.today

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

    # Split events: multi-day all-day vs everything else
    {multi_day_events, other_events} =
      Enum.split_with(assigns.events, fn e ->
        Event.all_day?(e) and Event.multi_day?(e)
      end)

    # Group non-multi-day events by date (includes single-day all-day + timed)
    events_by_date = DateHelpers.group_events_by_date(other_events, dates)

    # Group markers by date
    markers_by_date = PhoenixLiveSchedule.DayMarker.group_by_date(assigns.day_markers, dates)

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

    day_names =
      if assigns.show_weekends do
        I18n.ordered_day_names_short(assigns.week_start, assigns.translations)
      else
        I18n.ordered_day_names_short(assigns.week_start, assigns.translations)
        |> filter_weekday_names(assigns.week_start)
      end

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
        style={"grid-template-columns: #{if @show_week_numbers, do: "2rem ", else: ""}repeat(#{@days_per_week}, 1fr)"}
      >
        <div :if={@show_week_numbers} class="text-sm text-base-content text-center py-2">
          W
        </div>
        <div
          :for={name <- @day_names}
          class="cal-day-header text-sm font-semibold text-base-content uppercase tracking-wider py-2 text-center"
          role="columnheader"
        >
          {name}
        </div>
      </div>

      <%!-- Week rows --%>
      <div
        :for={{week, slot_data} <- @weeks}
        class="cal-week-row grid border-b border-base-content/8"
        style={"grid-template-columns: #{if @show_week_numbers, do: "2rem ", else: ""}repeat(#{@days_per_week}, 1fr)"}
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
            "cal-day-cell border-r border-base-content/5 relative",
            if(@expand_cells,
              do: "min-h-24 md:min-h-28 lg:min-h-32",
              else: "min-h-24 h-24 md:h-28 lg:h-32 overflow-hidden"
            ),
            cell_classes(day, @date, @today, @selected_date),
            marker_bg_class(Map.get(@markers_by_date, day, []))
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
                "cal-day-number text-sm w-5 h-5 inline-flex items-center justify-center flex-shrink-0",
                day_number_class(day, @date, @today)
              ]}>
                {day.day}
              </span>
              <.marker_ticker
                markers={Map.get(@markers_by_date, day, [])}
                enabled={@marker_ticker}
                interval={@marker_ticker_interval}
              />
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
                      event.color || "bg-primary",
                      event.text_color || Safe.infer_text_color(event.color),
                      multiday_rounding_class(is_start, is_end),
                      event.status == :cancelled && "opacity-50 line-through",
                      event.class,
                      highlight_class(event, day)
                    ]}
                    phx-click={@on_event_click}
                    phx-value-event-id={event.id}
                    title={event.title}
                    style={highlight_style(event, day)}
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

            <%!-- Single-day events: with margin for visual distinction --%>
            <div
              :for={event <- visible_single}
              class="mx-1 mt-px"
            >
              <%= if @event != [] do %>
                {render_slot(@event, event)}
              <% else %>
                <EventItem.event_item
                  event={event}
                  on_click={@on_event_click}
                  compact={true}
                  time_format={@time_format}
                />
              <% end %>
            </div>

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
    |> Enum.find(&PhoenixLiveSchedule.Event.on_date?(&1, day))
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
        marker_label_color(hd(@markers))
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
        marker_label_color(hd(@markers))
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
    ~H"""
    <div
      class="cal-marker-ticker grid min-w-0"
      phx-hook="MarkerTicker"
      data-interval={@interval}
      id={"ticker-#{:erlang.phash2(@markers)}"}
    >
      <span
        :for={{marker, idx} <- Enum.with_index(@markers)}
        class={[
          "col-start-1 row-start-1 cal-marker-label flex items-center text-[0.55rem] leading-none px-1 py-px rounded font-medium truncate transition-opacity duration-300",
          marker_label_color(marker),
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

  defp marker_label_color(%{type: :holiday}), do: "bg-error/30 text-error-content"
  defp marker_label_color(%{type: :closure}), do: "bg-warning/30 text-warning-content"
  defp marker_label_color(%{type: :notice}), do: "bg-info/20 text-info"
  defp marker_label_color(%{type: :label}), do: "bg-success/20 text-success"
  defp marker_label_color(%{type: :season}), do: "bg-accent/20 text-accent"
  defp marker_label_color(_), do: "bg-base-200 text-base-content/60"

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

  defp cell_classes(day, month_date, today, selected) do
    [
      not DateHelpers.in_month?(day, month_date) && "bg-base-content/[0.03]",
      day == today && "bg-primary/10",
      day == selected && day != today && "bg-secondary/10",
      DateHelpers.weekend?(day) && DateHelpers.in_month?(day, month_date) &&
        "bg-base-content/[0.02]"
    ]
  end

  defp marker_bg_class([]), do: nil

  defp marker_bg_class(markers) do
    cond do
      Enum.any?(markers, &(not &1.available and &1.type == :holiday)) ->
        "cal-day-holiday bg-error/8"

      Enum.any?(markers, &(not &1.available)) ->
        "cal-day-closed bg-error/5"

      Enum.any?(markers, &(&1.type == :notice)) ->
        "cal-day-notice bg-info/5"

      Enum.any?(markers, &(&1.type == :season)) ->
        "cal-day-season bg-accent/5"

      true ->
        nil
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

  defp event_start_date(%Event{} = e) do
    case e.start do
      %Date{} = d -> d
      %DateTime{} = dt -> DateTime.to_date(dt)
      %NaiveDateTime{} = ndt -> NaiveDateTime.to_date(ndt)
    end
  end

  defp event_end_date(%Event{} = e) do
    case Event.effective_end(e) do
      %Date{} = d -> d
      %DateTime{} = dt -> DateTime.to_date(dt)
      %NaiveDateTime{} = ndt -> NaiveDateTime.to_date(ndt)
    end
  end

  defp event_is_last_day?(event, day) do
    # Last day is end_date - 1 (since end is exclusive)
    end_date = event_end_date(event)
    Date.compare(Date.add(end_date, -1), day) == :eq
  end

  defp events_overlap_dates?(a, b) do
    a_start = event_start_date(a)
    a_end = event_end_date(a)
    b_start = event_start_date(b)
    b_end = event_end_date(b)

    Date.compare(a_start, b_end) == :lt and Date.compare(a_end, b_start) == :gt
  end

  defp filter_weekday_names(names, week_start) do
    days = Enum.map(0..6, fn offset -> rem(week_start - 1 + offset, 7) + 1 end)

    Enum.zip(days, names)
    |> Enum.reject(fn {day, _} -> day in [6, 7] end)
    |> Enum.map(fn {_, name} -> name end)
  end
end
