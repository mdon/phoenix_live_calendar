defmodule PhoenixLiveCalendar.Views.ResourceView do
  @moduledoc """
  Resource columns view — resources displayed as columns in a day/week time grid.

  Each resource gets its own column. Used for side-by-side comparison of
  schedules (e.g., multiple practitioners, rooms, or equipment).
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Components.{EventItem, TimeGutter}
  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils.TimeSlots

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
  - `show_now_indicator` — Show current time line (default: true)
  - `on_time_click` — Handler for time slot clicks
  - `on_event_click` — Handler for event clicks
  - `translations` — Translation overrides
  - `time_format` — `:h24` or `:h12` (default: `:h24`)
  - `class` — Additional CSS classes

  ## Slots

  - `event` — Custom event rendering
  - `resource_header` — Custom resource column header. Receives the resource.
  """
  attr :date, Date, required: true
  attr :resources, :list, required: true
  attr :events, :list, default: []
  attr :min_time, Time, default: ~T[00:00:00]
  attr :max_time, Time, default: ~T[23:59:59]
  attr :slot_duration, :integer, default: 30
  attr :slot_height, :string, default: "3rem"
  attr :show_now_indicator, :boolean, default: true
  attr :on_time_click, :any, default: nil
  attr :on_event_click, :any, default: nil
  attr :translations, :map, default: %{}
  attr :time_format, :atom, default: :h24
  attr :class, :string, default: ""

  slot :event
  slot :resource_header

  def resource_view(assigns) do
    slots =
      TimeSlots.time_grid_slots(
        min_time: assigns.min_time,
        max_time: assigns.max_time,
        slot_duration: assigns.slot_duration
      )

    events_by_resource =
      Enum.group_by(assigns.events, & &1.resource_id)

    now = Time.utc_now()
    today = Date.utc_today()
    col_count = length(assigns.resources)

    assigns =
      assigns
      |> assign(:slots, slots)
      |> assign(:events_by_resource, events_by_resource)
      |> assign(:now, now)
      |> assign(:today, today)
      |> assign(:col_count, col_count)

    ~H"""
    <div class={["cal-resource-view flex flex-col", @class]}>
      <%!-- Resource headers --%>
      <div class="cal-resource-headers flex border-b border-base-200">
        <div class="w-16 flex-shrink-0"></div>
        <div class="flex-1 grid" style={"grid-template-columns: repeat(#{@col_count}, 1fr)"}>
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

        <div class="flex-1 grid relative" style={"grid-template-columns: repeat(#{@col_count}, 1fr)"}>
          <div
            :for={resource <- @resources}
            class="cal-resource-column border-l border-base-200 relative"
            data-resource-id={resource.id}
          >
            <%!-- Slot grid lines --%>
            <div
              :for={slot <- @slots}
              class="cal-time-slot border-b border-base-200"
              style={"height: #{PhoenixLiveCalendar.Utils.Safe.sanitize_css_dimension(@slot_height)}"}
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
                class="absolute left-0.5 right-0.5 pointer-events-auto z-10"
                style={event_position_style(event, @min_time, @max_time)}
              >
                <%= if @event != [] do %>
                  {render_slot(@event, event)}
                <% else %>
                  <EventItem.event_item
                    event={event}
                    id_suffix={resource.id}
                    on_click={@on_event_click}
                    time_format={@time_format}
                    class="h-full text-xs bg-primary/80 text-primary-content border-l-2 border-primary"
                  />
                <% end %>
              </div>
            </div>

            <%!-- Now indicator --%>
            <TimeGutter.now_indicator
              :if={@show_now_indicator && @date == @today}
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

  defp event_position_style(event, min_time, max_time) do
    start_time = TimeSlots.to_time(event.start)
    end_time = TimeSlots.to_time(Event.effective_end(event))

    top = TimeSlots.time_to_percentage(start_time, min_time: min_time, max_time: max_time)
    bottom = TimeSlots.time_to_percentage(end_time, min_time: min_time, max_time: max_time)
    height = bottom - top

    "top: #{top}%; height: #{max(height, 1.5)}%"
  end
end
