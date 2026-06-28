defmodule PhoenixLiveSchedule.Views.WeekGrid do
  @moduledoc """
  Week time grid view — 7 day columns with a vertical time axis.

  Also used as the base for day view (1 column) and N-day view (N columns).
  """

  use Phoenix.Component

  alias PhoenixLiveSchedule.Components.{EventItem, TimeGutter}
  alias PhoenixLiveSchedule.Event
  alias PhoenixLiveSchedule.Utils.{DateHelpers, I18n, OverlapLayout, Safe, TimeSlots}

  @doc """
  Renders a week/day/N-day time grid.

  ## Attributes

  - `dates` — List of dates to display as columns
  - `events` — List of `PhoenixLiveSchedule.Event` structs
  - `selected_date` — Currently selected date
  - `today` — Today's date
  - `min_time` — Earliest visible time (default: `~T[00:00:00]`)
  - `max_time` — Latest visible time (default: `~T[23:59:59]`)
  - `slot_duration` — Slot duration in minutes (default: 30)
  - `slot_height` — CSS height per slot (default: "3rem")
  - `show_now_indicator` — Show current time line (default: true)
  - `show_all_day_row` — Show all-day event row (default: true)
  - `business_hours` — List of `PhoenixLiveSchedule.Availability` for highlighting
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
  attr :events, :list, default: []
  attr :selected_date, Date, default: nil
  attr :today, Date, default: nil
  attr :min_time, Time, default: ~T[00:00:00]
  attr :max_time, Time, default: ~T[23:59:59]
  attr :slot_duration, :integer, default: 30
  attr :slot_height, :string, default: "3rem"
  attr :show_now_indicator, :boolean, default: true
  attr :show_all_day_row, :boolean, default: true
  attr :business_hours, :list, default: []
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
    today = assigns.today || Date.utc_today()

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
    all_day_by_date = DateHelpers.group_events_by_date(all_day_events, assigns.dates)

    now = Time.utc_now()
    col_count = length(assigns.dates)

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
      |> assign(:all_day_by_date, all_day_by_date)
      |> assign(:overlap_layouts, overlap_layouts)
      |> assign(:now, now)
      |> assign(:col_count, col_count)

    ~H"""
    <div class={["cal-week-grid flex flex-col", @class]} dir={to_string(@dir)}>
      <%!-- Day headers --%>
      <div class="cal-week-header flex border-b border-base-200">
        <div class="w-16 flex-shrink-0"></div>
        <div class="flex-1 grid" style={"grid-template-columns: repeat(#{@col_count}, 1fr)"}>
          <div
            :for={date <- @dates}
            class={[
              "cal-day-column-header text-center py-2 border-l border-base-200",
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
              <span class="text-xs text-base-content/60">
                {I18n.day_name_short(Date.day_of_week(date), @translations)}
              </span>
              <br />
              <span class={[
                "text-lg font-medium",
                date == @today && "text-primary font-bold"
              ]}>
                {date.day}
              </span>
            </button>
            <div :if={!@on_date_click}>
              <span class="text-xs text-base-content/60">
                {I18n.day_name_short(Date.day_of_week(date), @translations)}
              </span>
              <br />
              <span class={[
                "text-lg font-medium",
                date == @today && "text-primary font-bold"
              ]}>
                {date.day}
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- All-day row with spanning bars --%>
      <div :if={@show_all_day_row} class="cal-all-day-row border-b border-base-200">
        <div class="flex">
          <div class="w-16 flex-shrink-0 text-xs text-base-content/50 text-center py-1">
            {I18n.label(:all_day, @translations)}
          </div>
          <div class="flex-1 relative">
            <%!-- Grid background for cell borders --%>
            <div
              class="grid absolute inset-0"
              style={"grid-template-columns: repeat(#{@col_count}, 1fr)"}
            >
              <div :for={_date <- @dates} class="border-l border-base-200"></div>
            </div>
            <%!-- Spanning event bars --%>
            <div
              class="grid relative min-h-6 py-0.5"
              style={"grid-template-columns: repeat(#{@col_count}, 1fr)"}
            >
              <% week_start = hd(@dates)
              week_end = Date.add(List.last(@dates), 1)
              # Multi-day all-day events as spanning bars
              multi_allday =
                Enum.filter(@all_day_events, fn e ->
                  Event.multi_day?(e) and Event.overlaps_range?(e, week_start, week_end)
                end)

              # Single-day all-day events
              single_allday =
                Enum.reject(@all_day_events, &Event.multi_day?/1)
                |> Enum.filter(fn e -> Event.overlaps_range?(e, week_start, week_end) end)

              all_bars = multi_allday ++ single_allday %>
              <div
                :for={event <- all_bars}
                class={[
                  "cal-spanning-bar rounded-sm px-1 py-0.5 text-xs font-medium truncate cursor-pointer mx-px mb-px",
                  event.color || "bg-primary",
                  event.text_color || Safe.infer_text_color(event.color),
                  event.status == :cancelled && "opacity-50 line-through"
                ]}
                style={allday_bar_style(event, week_start, week_end, @col_count)}
                phx-click={@on_event_click}
                phx-value-event-id={event.id}
                title={event.title}
              >
                <span :if={event.icon} class="mr-0.5">{event.icon}</span>
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

        <div class="flex-1 grid relative" style={"grid-template-columns: repeat(#{@col_count}, 1fr)"}>
          <%!-- Day columns --%>
          <div
            :for={date <- @dates}
            class={[
              "cal-day-column border-l border-base-200 relative",
              date == @today && "bg-primary/5"
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
              style={"height: #{PhoenixLiveSchedule.Utils.Safe.sanitize_css_dimension(@slot_height)}"}
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
                :for={event <- Map.get(@events_by_date, date, [])}
                class="absolute pointer-events-auto z-10"
                style={event_position_style_with_overlap(event, day_layout, @min_time, @max_time)}
              >
                <%= if @event != [] do %>
                  {render_slot(@event, event)}
                <% else %>
                  <EventItem.event_item
                    event={event}
                    on_click={@on_event_click}
                    time_format={@time_format}
                    class="h-full text-xs bg-primary/80 text-primary-content border-l-2 border-primary"
                  />
                <% end %>
              </div>
            </div>

            <%!-- Now indicator --%>
            <TimeGutter.now_indicator
              :if={@show_now_indicator && date == @today}
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

  defp event_position_style_with_overlap(event, layout_map, min_time, max_time) do
    start_time = TimeSlots.to_time(event.start)
    end_time = TimeSlots.to_time(Event.effective_end(event))

    top = TimeSlots.time_to_percentage(start_time, min_time: min_time, max_time: max_time)
    bottom = TimeSlots.time_to_percentage(end_time, min_time: min_time, max_time: max_time)
    height = bottom - top

    # Get overlap positioning (column and total_columns)
    overlap_info = Map.get(layout_map, event.id, %{column: 0, total_columns: 1})
    h_style = OverlapLayout.position_style(overlap_info)

    "top: #{top}%; height: #{max(height, 1.5)}%; #{h_style}"
  end

  defp slot_business_class(_date, _slot_time, []), do: nil

  defp slot_business_class(date, slot_time, business_hours) do
    windows = PhoenixLiveSchedule.Availability.windows_for_date(business_hours, date)

    is_business =
      Enum.any?(windows, fn w ->
        w.available and PhoenixLiveSchedule.Availability.covers_time?(w, slot_time)
      end)

    unless is_business, do: "bg-base-200/30"
  end

  defp allday_bar_style(event, week_start, week_end, col_count) do
    event_start = to_date(event.start)
    event_end = to_date(Event.effective_end(event))

    vis_start = if Date.compare(event_start, week_start) == :lt, do: week_start, else: event_start
    vis_end = if Date.compare(event_end, week_end) == :gt, do: week_end, else: event_end

    col_start = max(Date.diff(vis_start, week_start) + 1, 1)
    col_span = max(Date.diff(vis_end, vis_start), 1)
    col_span = min(col_span, col_count - col_start + 1)

    "grid-column: #{col_start} / span #{col_span}"
  end

  defp to_date(%Date{} = d), do: d
  defp to_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp to_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt)
end
