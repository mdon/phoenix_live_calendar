defmodule PhoenixLiveCalendar.Views.ResourceView do
  @moduledoc """
  Resource columns view — resources displayed as columns in a day/week time grid.

  Each resource gets its own column. Used for side-by-side comparison of
  schedules (e.g., multiple practitioners, rooms, or equipment).
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Components.{EventItem, TimeGutter}
  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils.{Safe, Sizing, TimeSlots}

  @doc """
  Renders a resource-column time grid.

  ## Attributes

  - `date` — The date to display
  - `resources` — List of `PhoenixLiveCalendar.Resource` structs (one column each)
  - `events` — List of `PhoenixLiveCalendar.Event` structs (linked via resource_id)
  - `min_time` — Earliest visible time (default: `~T[00:00:00]`)
  - `max_time` — Latest visible time (default: `~T[23:59:59]`)
  - `slot_duration` — Slot duration in minutes (default: 30)
  - `slot_height` — CSS height per slot (default: "3rem")
  - `show_now_indicator` — Show current time line (default: true; hidden
    when `now` falls outside the visible window)
  - `today` — Today's date for the now indicator (default: `Date.utc_today()`)
  - `now` — Current wall-clock time (default: `Time.utc_now()`)
  - `event_content` — `:auto` (default) tiers each block's content by its
    estimated height, like the week grid; pass a tier to force it
  - `min_event_height` — CSS floor for a block's height (default
    `"1.25rem"`; `"0"` disables)
  - `on_time_click` — Handler for time slot clicks
  - `on_event_click` — Handler for event clicks
  - `translations` — Translation overrides
  - `time_format` — `:h24` or `:h12` (default: `:h24`)
  - `class` — Additional CSS classes
  - `dir` — Text direction (default: `:ltr`)

  Events are filtered to those occupying `date` (an event may target a
  column via `resource_id` or the plural `resource_ids`); midnight-crossing
  events clamp to the date like the week grid and timeline.

  ## Slots

  - `event` — Custom event rendering
  - `resource_header` — Custom resource column header. Receives the resource.
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
  attr :slot_duration, :integer, default: 30
  attr :slot_height, :string, default: "3rem"
  attr :show_now_indicator, :boolean, default: true
  attr :today, Date, default: nil
  attr :now, Time, default: nil

  attr :event_content, :atom,
    default: :auto,
    values: [:auto, :detail, :inline, :title, :none]

  attr :min_event_height, :string, default: "1.25rem"
  attr :on_time_click, :any, default: nil
  attr :on_event_click, :any, default: nil
  attr :translations, :map, default: %{}
  attr :time_format, :atom, default: :h24
  attr :class, :string, default: ""
  attr :dir, :atom, default: :ltr

  slot :event
  slot :resource_header

  def resource_view(assigns) do
    slots =
      TimeSlots.time_grid_slots(
        min_time: assigns.min_time,
        max_time: assigns.max_time,
        slot_duration: assigns.slot_duration
      )

    # Only events occupying the displayed date render (an off-date event
    # used to position by raw time-of-day); resource_ids (plural) targets
    # an event at several columns.
    day_events = Enum.filter(assigns.events, &Event.on_date?(&1, assigns.date))

    events_by_resource =
      Map.new(assigns.resources, fn resource ->
        {resource.id, Enum.filter(day_events, &Event.on_resource?(&1, resource.id))}
      end)

    now = assigns.now || Time.utc_now()
    today = assigns.today || Date.utc_today()
    col_count = length(assigns.resources)

    rem_per_minute =
      Sizing.parse_rem(assigns.slot_height, 3.0) / max(assigns.slot_duration, 1)

    assigns =
      assigns
      |> assign(:slots, slots)
      |> assign(:events_by_resource, events_by_resource)
      |> assign(:now, now)
      |> assign(:today, today)
      |> assign(:col_count, col_count)
      |> assign(:rem_per_minute, rem_per_minute)
      |> assign(
        :now_in_window?,
        Time.compare(now, assigns.min_time) != :lt and
          Time.compare(now, assigns.max_time) != :gt
      )

    ~H"""
    <div class={["cal-resource-view flex flex-col", @class]} dir={to_string(@dir)}>
      <%!-- Resource headers --%>
      <div class="cal-resource-headers flex border-b border-base-200">
        <div class="w-16 flex-shrink-0"></div>
        <div class="flex-1 grid" style={"grid-template-columns: repeat(#{@col_count}, minmax(0, 1fr))"}>
          <div
            :for={resource <- @resources}
            class="cal-resource-column-header text-center py-2 border-l border-base-200"
          >
            <%= if @resource_header != [] do %>
              {render_slot(@resource_header, resource)}
            <% else %>
              <div class="flex items-center justify-center gap-1">
                <div
                  :if={resource.color}
                  class={["w-2 h-2 rounded-full", resource.color]}
                >
                </div>
                <span class="text-sm font-medium">{resource.title}</span>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Time grid body --%>
      <div class="cal-resource-body flex flex-1 overflow-y-auto">
        <TimeGutter.time_gutter
          slots={@slots}
          slot_height={@slot_height}
          time_format={@time_format}
        />

        <div
          class="flex-1 grid relative"
          style={"grid-template-columns: repeat(#{@col_count}, minmax(0, 1fr))"}
        >
          <div
            :for={resource <- @resources}
            class="cal-resource-column border-l border-base-200 relative"
            data-resource-id={resource.id}
          >
            <%!-- Slot grid lines --%>
            <div
              :for={slot <- @slots}
              class="cal-time-slot border-b border-base-200"
              style={"height: #{Safe.sanitize_css_dimension(@slot_height)}"}
              phx-click={@on_time_click}
              phx-value-resource-id={resource.id}
              phx-value-date={Date.to_iso8601(@date)}
              phx-value-time={Time.to_iso8601(slot)}
            >
            </div>

            <%!-- Positioned events --%>
            <div class="absolute inset-0 pointer-events-none">
              <div
                :for={event <- Map.get(@events_by_resource, resource.id, [])}
                :if={Event.day_window(event, @date, @min_time, @max_time)}
                class="absolute start-0.5 end-0.5 pointer-events-auto z-10"
                style={event_position_style(event, @date, @min_time, @max_time, @min_event_height)}
              >
                <%= if @event != [] do %>
                  {render_slot(@event, event)}
                <% else %>
                  <EventItem.event_item
                    event={event}
                    content={
                      event_tier(event, @date, @event_content, @min_time, @max_time, @rem_per_minute)
                    }
                    id_suffix={EventItem.instance_suffix(@id, resource.id)}
                    on_click={@on_event_click}
                    time_format={@time_format}
                    default_color="bg-primary/80"
                    class="h-full text-xs border-s-2 border-primary"
                  />
                <% end %>
              </div>
            </div>

            <%!-- Now indicator --%>
            <TimeGutter.now_indicator
              :if={@show_now_indicator && @date == @today && @now_in_window?}
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

  # Shared per-day segment rule + the rem floor (the old 1.5% floor changed
  # real size with the visible window) — the week grid's geometry.
  defp event_position_style(event, date, min_time, max_time, min_height) do
    {start_time, end_time} = Event.day_window(event, date, min_time, max_time)

    top = TimeSlots.time_to_percentage(start_time, min_time: min_time, max_time: max_time)
    bottom = TimeSlots.time_to_percentage(end_time, min_time: min_time, max_time: max_time)
    height = bottom - top

    case Safe.height_floor(min_height) do
      nil -> "top: #{top}%; height: #{height}%"
      floor -> "top: min(#{top}%, calc(100% - #{floor})); height: max(#{height}%, #{floor})"
    end
  end

  defp event_tier(event, date, :auto, min_time, max_time, rem_per_minute) do
    {seg_start, seg_end} = Event.day_window(event, date, min_time, max_time)
    EventItem.tier_for_height(Time.diff(seg_end, seg_start) / 60 * rem_per_minute)
  end

  defp event_tier(_event, _date, forced, _min, _max, _rpm), do: forced
end
