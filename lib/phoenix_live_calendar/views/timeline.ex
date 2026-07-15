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
    Off = the caller pre-filters; every event in `events` renders
  - `clamp_to_date` — Clamp each event's bar to the intersection of its span
    with `date`, so midnight-crossing events position correctly on both days
    (default: `true`). Off = bars position by raw time-of-day (an event
    crossing midnight renders wrong — pre-0.2.0 behavior)
  - `sticky_resource_column` — Keep the resource label column pinned during
    horizontal scroll (default: `true`)
  - `show_now_indicator` — Vertical current-time line when `date` is today
    (default: `true`, matching the day/week grids)
  - `today` — Today's date, for the now indicator (default: `Date.utc_today()`)
  - `fit_to_events` — Compute the visible window from the rendered events
    instead of `min_time`/`max_time`: earliest start floored to the hour,
    latest end ceiled to the hour (default: `false`). Falls back to
    `min_time`/`max_time` when no timed events render
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
  attr :show_now_indicator, :boolean, default: true
  attr :today, Date, default: nil
  attr :fit_to_events, :boolean, default: false
  attr :on_event_click, :any, default: nil
  attr :on_slot_click, :any, default: nil
  attr :translations, :map, default: %{}
  attr :time_format, :atom, default: :h24
  attr :class, :string, default: ""
  attr :dir, :atom, default: :ltr

  slot :event
  slot :resource_label

  def timeline(assigns) do
    events =
      if assigns.filter_to_date,
        do: Enum.filter(assigns.events, &Event.on_date?(&1, assigns.date)),
        else: assigns.events

    {min_time, max_time} = visible_window(assigns, events)

    slots =
      TimeSlots.time_grid_slots(
        min_time: min_time,
        max_time: max_time,
        slot_duration: assigns.slot_duration
      )

    # Group events by resource
    events_by_resource =
      Enum.group_by(events, fn event ->
        event.resource_id
      end)

    today = assigns.today || Date.utc_today()

    now_pct =
      if assigns.show_now_indicator and assigns.date == today do
        TimeSlots.time_to_percentage(Time.utc_now(), min_time: min_time, max_time: max_time)
      end

    assigns =
      assigns
      |> assign(:slots, slots)
      |> assign(:events_by_resource, events_by_resource)
      |> assign(:min_time, min_time)
      |> assign(:max_time, max_time)
      |> assign(:now_pct, now_pct)

    ~H"""
    <div class={["cal-timeline overflow-x-auto", @class]} dir={to_string(@dir)}>
      <div class="inline-flex flex-col min-w-full">
        <%!-- Time header --%>
        <div class="cal-timeline-header flex border-b border-base-200 sticky top-0 bg-base-100 z-10">
          <div
            class={[
              "cal-timeline-resource-header flex-shrink-0 border-r border-base-200 px-2 py-2 font-medium text-sm",
              @sticky_resource_column && "sticky left-0 z-30 bg-base-100"
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
              @sticky_resource_column && "sticky left-0 z-20 bg-base-100"
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
                 as a single continuous vertical line --%>
            <div
              :if={@now_pct}
              class="cal-timeline-now-indicator absolute top-0 bottom-0 w-px bg-error z-20 pointer-events-none"
              style={"left: #{@now_pct}%"}
              aria-hidden="true"
            >
            </div>

            <%!-- Positioned events for this resource --%>
            <div class="absolute inset-0 pointer-events-none py-0.5">
              <div
                :for={event <- Map.get(@events_by_resource, resource.id, [])}
                class="absolute top-0.5 bottom-0.5 pointer-events-auto z-10"
                style={timeline_event_style(event, @date, @min_time, @max_time, @clamp_to_date)}
              >
                <%= if @event != [] do %>
                  {render_slot(@event, event)}
                <% else %>
                  <EventItem.event_item
                    event={event}
                    id_suffix={resource.id}
                    on_click={@on_event_click}
                    default_color="bg-primary/80"
                    class="h-full text-xs rounded px-1"
                  />
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp timeline_event_style(event, date, min_time, max_time, clamp) do
    {start_time, end_time} = event_window(event, date, clamp)

    start_pct = TimeSlots.time_to_percentage(start_time, min_time: min_time, max_time: max_time)
    end_pct = TimeSlots.time_to_percentage(end_time, min_time: min_time, max_time: max_time)

    "left: #{start_pct}%; width: #{max(end_pct - start_pct, 2.0)}%"
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
  # stretch across whatever window results). No timed events → the attrs.
  defp visible_window(%{fit_to_events: false} = assigns, _events) do
    {assigns.min_time, assigns.max_time}
  end

  defp visible_window(assigns, events) do
    windows =
      events
      |> Enum.reject(&Event.all_day?/1)
      |> Enum.map(&event_window(&1, assigns.date, assigns.clamp_to_date))

    case windows do
      [] ->
        {assigns.min_time, assigns.max_time}

      _ ->
        earliest = windows |> Enum.map(&elem(&1, 0)) |> Enum.min(Time)
        latest = windows |> Enum.map(&elem(&1, 1)) |> Enum.max(Time)
        {floor_to_hour(earliest), ceil_to_hour(latest)}
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
