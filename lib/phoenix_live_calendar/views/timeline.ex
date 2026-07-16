defmodule PhoenixLiveCalendar.Views.Timeline do
  @moduledoc """
  Timeline view — horizontal time axis with resources as rows.

  Used for resource scheduling (rooms, people, equipment),
  Gantt-style project views, and multi-resource booking.

  Events are filtered to the rendered `date` and midnight-crossing events are
  clamped to it (a 23:50 → 00:20 session renders as 23:50 → 24:00 on day one
  and 00:00 → 00:20 on day two); both behaviors have opt-out attrs.
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Components.EventItem
  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils
  alias PhoenixLiveCalendar.Utils.{I18n, TimeSlots}

  @day_start ~T[00:00:00]
  @day_end ~T[23:59:59]

  @doc """
  Renders a horizontal timeline with resource rows.

  ## Attributes

  - `date` — The date to display
  - `resources` — List of `PhoenixLiveCalendar.Resource` structs
  - `events` — List of `PhoenixLiveCalendar.Event` structs (linked to resources via resource_id)
  - `min_time` — Earliest visible time (default: `~T[00:00:00]`)
  - `max_time` — Latest visible time (default: `~T[23:59:59]`)
  - `slot_duration` — Slot duration in minutes (default: 60)
  - `slot_width` — CSS width per time slot (default: "5rem")
  - `resource_width` — CSS width for the resource label column (default: "12rem")
  - `filter_to_date` — Only render events that occupy `date` (default: `true`).
    Off = the caller pre-filters; every event in `events` renders. Note that
    `clamp_to_date` also implies this filter — an event that never touches
    the date has an empty intersection with it, so there is nothing to draw
  - `clamp_to_date` — Clamp each event's bar to the intersection of its span
    with `date`, so midnight-crossing events position correctly on both days
    (default: `true`). Off = bars position by raw time-of-day (an event
    crossing midnight renders wrong — pre-0.2.0 behavior)
  - `sticky_resource_column` — Keep the resource label column pinned during
    horizontal scroll (default: `true`)
  - `show_now_indicator` — Vertical current-time line when `date` is today
    and the current time falls inside the visible window (default: `true`,
    matching the day/week grids)
  - `today` — Today's date, for the now indicator (default: `Date.utc_today()`)
  - `now` — Current wall-clock time for the now indicator (default:
    `Time.utc_now()`). Pass the viewer's local time when your events/`today`
    are in the viewer's frame
  - `fit_to_events` — Compute the visible window from the rendered events
    instead of `min_time`/`max_time`: earliest start floored to the hour,
    latest end ceiled to the hour (default: `false`). Falls back to
    `min_time`/`max_time` when no timed events render or when the computed
    window would be empty/inverted
  - `label_position` — where bar labels go: `:fit` (default) renders the
    label inside the bar when the server-side estimate says it fits, else
    falls back per `label_fit_fallback`; `:inside` always in-bar (truncated);
    `:outside` always beside the bar; `:none` no labels (tooltip + aria
    still identify every bar)
  - `label_fit_ratio` — how much of the estimated label must fit for
    `:fit` to choose inside (default `0.75`)
  - `label_fit_fallback` — `:outside` (default) or `:none`; outside labels
    place after the bar, flip before it at the track edge, and suppress
    themselves rather than overprint a neighbouring bar or label
  - `on_event_click` — Handler for event clicks
  - `on_slot_click` — Handler for time slot clicks
  - `translations` — Translation overrides
  - `time_format` — `:h24` or `:h12` (default: `:h24`)
  - `class` — Additional CSS classes
  - `dir` — Text direction (default: `:ltr`)

  ## Slots

  - `event` — Custom event rendering
  - `resource_label` — Custom resource label. Receives the resource.

  All-day events covering `date` render as full-width bars.
  """
  attr :date, Date, required: true

  attr :id, :string,
    default: nil,
    doc:
      "Optional prefix for generated event DOM ids. Set it when two views on one page can render the SAME events — without it their per-event ids collide."

  attr :resources, :list, required: true
  attr :events, :list, default: []
  attr :min_time, Time, default: ~T[00:00:00]
  attr :max_time, Time, default: ~T[23:59:59]
  attr :slot_duration, :integer, default: 60
  attr :slot_width, :string, default: "5rem"
  attr :resource_width, :string, default: "12rem"
  attr :filter_to_date, :boolean, default: true
  attr :clamp_to_date, :boolean, default: true
  attr :sticky_resource_column, :boolean, default: true
  attr :show_time_axis, :boolean, default: true
  attr :show_now_indicator, :boolean, default: true
  attr :today, Date, default: nil
  attr :now, Time, default: nil
  attr :fit_to_events, :boolean, default: false
  attr :label_position, :atom, default: :fit, values: [:none, :inside, :outside, :fit]
  attr :label_fit_ratio, :float, default: 0.75
  attr :label_fit_fallback, :atom, default: :outside, values: [:outside, :none]
  attr :on_event_click, :any, default: nil
  attr :on_slot_click, :any, default: nil
  attr :translations, :map, default: %{}
  attr :time_format, :atom, default: :h24
  attr :class, :string, default: ""
  attr :dir, :atom, default: :ltr

  slot :event
  slot :resource_label

  def timeline(assigns) do
    # clamp_to_date implies the date filter: with clamping, an event's bar is
    # its intersection with the date — no intersection means nothing to draw
    # (one-sided clamping of an off-date event would fabricate a bar).
    events =
      if assigns.filter_to_date or assigns.clamp_to_date,
        do: Enum.filter(assigns.events, &Event.on_date?(&1, assigns.date)),
        else: assigns.events

    {min_time, max_time} = visible_window(assigns, events)

    slots =
      TimeSlots.time_grid_slots(
        min_time: min_time,
        max_time: max_time,
        slot_duration: assigns.slot_duration
      )

    # Group events by resource, then lay each row's bars + labels out
    track_rem =
      max(Utils.Sizing.parse_rem(assigns.slot_width, 5.0) * max(length(slots), 1), 1.0)

    bars_by_resource =
      events
      |> Enum.group_by(fn event -> event.resource_id end)
      |> Map.new(fn {resource_id, row_events} ->
        {resource_id, row_bars(row_events, assigns, min_time, max_time, track_rem)}
      end)

    today = assigns.today || Date.utc_today()
    now = assigns.now || Time.utc_now()

    # Hidden when the current time falls outside the visible window —
    # time_to_percentage would clamp it to 0/100 and draw a false line
    # pinned at the window edge (fit_to_events windows especially).
    now_pct =
      if assigns.show_now_indicator and assigns.date == today and
           Time.compare(now, min_time) != :lt and Time.compare(now, max_time) != :gt do
        TimeSlots.time_to_percentage(now, min_time: min_time, max_time: max_time)
      end

    assigns =
      assigns
      |> assign(:slots, slots)
      |> assign(:bars_by_resource, bars_by_resource)
      |> assign(:min_time, min_time)
      |> assign(:max_time, max_time)
      |> assign(:now_pct, now_pct)

    ~H"""
    <div class={["cal-timeline overflow-x-auto", @class]} dir={to_string(@dir)}>
      <div class="inline-flex flex-col min-w-full">
        <%!-- Time header. z-30: the header band must paint over the sticky
             row labels (z-20) and event bars (z-10) when rows scroll under
             it vertically — its own children's z-values are scoped inside. --%>
        <div
          :if={@show_time_axis}
          class="cal-timeline-header flex border-b border-base-200 sticky top-0 bg-base-100 z-30"
        >
          <div
            class={[
              "cal-timeline-resource-header flex-shrink-0 border-r border-base-200 px-2 py-2 font-medium text-sm",
              @sticky_resource_column && "sticky start-0 z-30 bg-base-100"
            ]}
            style={"width: #{PhoenixLiveCalendar.Utils.Safe.sanitize_css_dimension(@resource_width)}"}
          >
          </div>
          <div class="flex">
            <div
              :for={slot <- @slots}
              class="cal-timeline-time-header text-xs text-base-content/60 text-center border-r border-base-200 py-2"
              style={"width: #{PhoenixLiveCalendar.Utils.Safe.sanitize_css_dimension(@slot_width)}"}
            >
              {I18n.format_time(slot, format: @time_format)}
            </div>
          </div>
        </div>

        <%!-- Resource rows --%>
        <div
          :for={resource <- @resources}
          class="cal-timeline-row flex border-b border-base-200 hover:bg-base-200/20"
        >
          <%!-- Resource label --%>
          <div
            class={[
              "cal-timeline-resource-label flex-shrink-0 border-r border-base-200 px-2 py-2 flex items-center",
              @sticky_resource_column && "sticky start-0 z-20 bg-base-100"
            ]}
            style={"width: #{PhoenixLiveCalendar.Utils.Safe.sanitize_css_dimension(@resource_width)}"}
          >
            <%= if @resource_label != [] do %>
              {render_slot(@resource_label, resource)}
            <% else %>
              <div class="flex items-center gap-2">
                <div
                  :if={resource.color}
                  class={["w-2 h-2 rounded-full", resource.color]}
                >
                </div>
                <span class="text-sm font-medium truncate">{resource.title}</span>
              </div>
            <% end %>
          </div>

          <%!-- Time slots with events --%>
          <div class="flex relative">
            <div
              :for={slot <- @slots}
              class="cal-timeline-slot border-r border-base-200"
              style={"width: #{PhoenixLiveCalendar.Utils.Safe.sanitize_css_dimension(@slot_width)}; min-height: 3rem;"}
              phx-click={@on_slot_click}
              phx-value-resource-id={resource.id}
              phx-value-date={Date.to_iso8601(@date)}
              phx-value-time={Time.to_iso8601(slot)}
            >
            </div>

            <%!-- Now indicator: one segment per row, so the stacked rows read
                 as a single continuous vertical line. z-10 keeps it UNDER the
                 sticky labels (z-20); inset-inline-start mirrors under RTL. --%>
            <div
              :if={@now_pct}
              class="cal-timeline-now-indicator absolute top-0 bottom-0 w-px bg-error z-10 pointer-events-none"
              style={"inset-inline-start: #{@now_pct}%"}
              aria-hidden="true"
            >
            </div>

            <%!-- Positioned events for this resource --%>
            <div class="absolute inset-0 pointer-events-none py-0.5">
              <div
                :for={bar <- Map.get(@bars_by_resource, resource.id, [])}
                class="absolute top-0.5 bottom-0.5 pointer-events-auto z-10"
                style={bar.style}
              >
                <%= if @event != [] do %>
                  {render_slot(@event, bar.event)}
                <% else %>
                  <EventItem.event_item
                    event={bar.event}
                    content={bar.content}
                    id_suffix={instance_suffix(@id, resource.id)}
                    on_click={@on_event_click}
                    default_color="bg-primary/80"
                    class="h-full text-xs rounded px-1"
                  />
                <% end %>
              </div>
              <%!-- Outside labels: beside bars too narrow for their text —
                   suppressed (tooltip only) rather than overprinting --%>
              <span
                :for={bar <- Map.get(@bars_by_resource, resource.id, [])}
                :if={@event == [] and bar.label != nil}
                class="cal-timeline-bar-label absolute top-1/2 -translate-y-1/2 text-xs text-base-content/70 whitespace-nowrap overflow-hidden text-ellipsis pointer-events-none"
                style={"inset-inline-start: #{bar.label.at}%; max-width: #{bar.label.max_w}%"}
              >
                {bar.label.text}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp instance_suffix(nil, key), do: key
  defp instance_suffix(id, key), do: "#{id}-#{key}"

  # Lay out one resource row: bar geometry, per-bar content tier, and
  # outside-label placement with a greedy no-overprint guard.
  defp row_bars(row_events, assigns, min_time, max_time, track_rem) do
    placed =
      row_events
      |> Enum.map(fn event ->
        {start_pct, width} =
          bar_geometry(event, assigns.date, min_time, max_time, assigns.clamp_to_date)

        %{event: event, start: start_pct, width: width}
      end)
      |> Enum.sort_by(& &1.start)

    bar_spans = Enum.map(placed, fn bar -> {bar.start, bar.start + bar.width} end)

    {bars, _label_spans} =
      Enum.map_reduce(placed, [], fn bar, label_spans ->
        decide_label(bar, assigns, track_rem, bar_spans, label_spans)
      end)

    bars
  end

  defp decide_label(bar, assigns, track_rem, bar_spans, label_spans) do
    style = "inset-inline-start: #{bar.start}%; width: #{bar.width}%"
    title = bar.event.title || ""

    case label_mode(bar, assigns, track_rem, title) do
      :inside ->
        {%{event: bar.event, style: style, content: :inline, label: nil}, label_spans}

      :none ->
        {%{event: bar.event, style: style, content: :none, label: nil}, label_spans}

      :outside ->
        place_outside(bar, style, title, track_rem, bar_spans, label_spans)
    end
  end

  defp label_mode(_bar, %{label_position: :none}, _track_rem, _title), do: :none
  defp label_mode(_bar, %{label_position: :inside}, _track_rem, _title), do: :inside
  defp label_mode(_bar, %{label_position: :outside}, _track_rem, _title), do: :outside

  defp label_mode(bar, %{label_position: :fit} = assigns, track_rem, title) do
    bar_rem = bar.width / 100 * track_rem

    # the inside content is "HH:MM Title" — ~6 extra characters
    inside_rem = Utils.Sizing.label_rem(title) + 6 * 0.45

    if bar_rem >= inside_rem * assigns.label_fit_ratio and bar_rem >= 2.0,
      do: :inside,
      else: assigns.label_fit_fallback
  end

  # After the bar's end, flipped before it at the track edge, suppressed
  # when neither gap is free — never overprinting a bar or another label.
  defp place_outside(bar, style, title, track_rem, bar_spans, label_spans) do
    label_pct = min(Utils.Sizing.label_rem(title) / track_rem * 100, 25.0)
    taken = bar_spans ++ label_spans
    bar_end = bar.start + bar.width

    candidates =
      if title == "",
        do: [],
        else: [
          {bar_end + 0.3, bar_end + 0.3 + label_pct},
          {bar.start - 0.3 - label_pct, bar.start - 0.3}
        ]

    case Enum.find(candidates, fn {from, to} -> free?(from, to, taken) end) do
      nil ->
        {%{event: bar.event, style: style, content: :none, label: nil}, label_spans}

      {from, to} = span ->
        {%{
           event: bar.event,
           style: style,
           content: :none,
           label: %{at: from, max_w: to - from, text: title}
         }, [span | label_spans]}
    end
  end

  # No overlap with any reserved interval, and inside the track.
  defp free?(from, to, taken) do
    from >= 0.0 and to <= 100.0 and
      not Enum.any?(taken, fn {a, b} -> from < b - 0.01 and to > a + 0.01 end)
  end

  defp bar_geometry(event, date, min_time, max_time, clamp) do
    {start_time, end_time} = event_window(event, date, clamp)

    start_pct = TimeSlots.time_to_percentage(start_time, min_time: min_time, max_time: max_time)
    end_pct = TimeSlots.time_to_percentage(end_time, min_time: min_time, max_time: max_time)

    # Width floor first, then pull the start back so the bar never overruns
    # the track (an end-of-day stub at 99.31% + a 2% floor = 101.31% without
    # this). inset-inline-start (not left) mirrors correctly under RTL.
    width = max(end_pct - start_pct, 2.0)
    start_pct = start_pct |> min(100.0 - width) |> max(0.0)

    {start_pct, width}
  end

  # The times an event's bar occupies on the rendered date. With clamping,
  # the bar is the intersection of [start, effective_end] with the date —
  # a midnight-crossing event runs to 24:00 on its first day and from 00:00
  # on its last. Without clamping, raw time-of-day (pre-0.2.0 behavior).
  # All-day events carry no times, so they span the whole day either way.
  defp event_window(event, date, clamp) do
    cond do
      Event.all_day?(event) ->
        {@day_start, @day_end}

      clamp ->
        event_end = Event.effective_end(event)

        start_time =
          if Date.compare(to_date(event.start), date) == :lt,
            do: @day_start,
            else: TimeSlots.to_time(event.start)

        end_time =
          if Date.compare(to_date(event_end), date) == :gt,
            do: @day_end,
            else: TimeSlots.to_time(event_end)

        {start_time, end_time}

      true ->
        {TimeSlots.to_time(event.start), TimeSlots.to_time(Event.effective_end(event))}
    end
  end

  # fit_to_events: the visible window hugs the rendered events — earliest
  # start floored to the hour, latest end ceiled to the hour. All-day events
  # are excluded (they'd force a full 0–24 window and defeat the fit; they
  # stretch across whatever window results), as are events without a rendered
  # resource row (they never draw, so they must not stretch the axis).
  # No timed events, or a degenerate/inverted computed window (zero-duration
  # event on an exact hour; unclamped midnight-crossers) → the attrs, never
  # a blank axis.
  defp visible_window(%{fit_to_events: false} = assigns, _events) do
    {assigns.min_time, assigns.max_time}
  end

  defp visible_window(assigns, events) do
    rendered_resources = MapSet.new(assigns.resources, & &1.id)

    windows =
      events
      |> Enum.reject(&Event.all_day?/1)
      |> Enum.filter(&MapSet.member?(rendered_resources, &1.resource_id))
      |> Enum.map(&event_window(&1, assigns.date, assigns.clamp_to_date))

    with [_ | _] <- windows,
         earliest = windows |> Enum.map(&elem(&1, 0)) |> Enum.min(Time),
         latest = windows |> Enum.map(&elem(&1, 1)) |> Enum.max(Time),
         {min_time, max_time} = {floor_to_hour(earliest), ceil_to_hour(latest)},
         :lt <- Time.compare(min_time, max_time) do
      {min_time, max_time}
    else
      _ -> {assigns.min_time, assigns.max_time}
    end
  end

  defp floor_to_hour(%Time{} = t), do: Time.new!(t.hour, 0, 0)

  defp ceil_to_hour(%Time{minute: 0, second: 0} = t), do: t
  defp ceil_to_hour(%Time{hour: 23}), do: @day_end
  defp ceil_to_hour(%Time{} = t), do: Time.new!(t.hour + 1, 0, 0)

  defp to_date(%Date{} = d), do: d
  defp to_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp to_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt)
end
