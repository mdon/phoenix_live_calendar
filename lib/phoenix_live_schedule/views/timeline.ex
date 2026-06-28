defmodule PhoenixLiveSchedule.Views.Timeline do
  @moduledoc """
  Timeline view — horizontal time axis with resources as rows.

  Used for resource scheduling (rooms, people, equipment),
  Gantt-style project views, and multi-resource booking.
  """

  use Phoenix.Component

  alias PhoenixLiveSchedule.Components.EventItem
  alias PhoenixLiveSchedule.Event
  alias PhoenixLiveSchedule.Utils.{I18n, TimeSlots}

  @doc """
  Renders a horizontal timeline with resource rows.

  ## Attributes

  - `date` — The date to display
  - `resources` — List of `PhoenixLiveSchedule.Resource` structs
  - `events` — List of `PhoenixLiveSchedule.Event` structs (linked to resources via resource_id)
  - `min_time` — Earliest visible time (default: `~T[00:00:00]`)
  - `max_time` — Latest visible time (default: `~T[23:59:59]`)
  - `slot_duration` — Slot duration in minutes (default: 60)
  - `slot_width` — CSS width per time slot (default: "5rem")
  - `resource_width` — CSS width for the resource label column (default: "12rem")
  - `on_event_click` — Handler for event clicks
  - `on_slot_click` — Handler for time slot clicks
  - `translations` — Translation overrides
  - `time_format` — `:h24` or `:h12` (default: `:h24`)
  - `class` — Additional CSS classes
  - `dir` — Text direction (default: `:ltr`)

  ## Slots

  - `event` — Custom event rendering
  - `resource_label` — Custom resource label. Receives the resource.
  """
  attr :date, Date, required: true
  attr :resources, :list, required: true
  attr :events, :list, default: []
  attr :min_time, Time, default: ~T[00:00:00]
  attr :max_time, Time, default: ~T[23:59:59]
  attr :slot_duration, :integer, default: 60
  attr :slot_width, :string, default: "5rem"
  attr :resource_width, :string, default: "12rem"
  attr :on_event_click, :any, default: nil
  attr :on_slot_click, :any, default: nil
  attr :translations, :map, default: %{}
  attr :time_format, :atom, default: :h24
  attr :class, :string, default: ""
  attr :dir, :atom, default: :ltr

  slot :event
  slot :resource_label

  def timeline(assigns) do
    slots =
      TimeSlots.time_grid_slots(
        min_time: assigns.min_time,
        max_time: assigns.max_time,
        slot_duration: assigns.slot_duration
      )

    # Group events by resource
    events_by_resource =
      Enum.group_by(assigns.events, fn event ->
        event.resource_id
      end)

    assigns =
      assigns
      |> assign(:slots, slots)
      |> assign(:events_by_resource, events_by_resource)

    ~H"""
    <div class={["cal-timeline overflow-x-auto", @class]} dir={to_string(@dir)}>
      <div class="inline-flex flex-col min-w-full">
        <%!-- Time header --%>
        <div class="cal-timeline-header flex border-b border-base-200 sticky top-0 bg-base-100 z-10">
          <div
            class="cal-timeline-resource-header flex-shrink-0 border-r border-base-200 px-2 py-2 font-medium text-sm"
            style={"width: #{PhoenixLiveSchedule.Utils.Safe.sanitize_css_dimension(@resource_width)}"}
          >
          </div>
          <div class="flex">
            <div
              :for={slot <- @slots}
              class="cal-timeline-time-header text-xs text-base-content/60 text-center border-r border-base-200 py-2"
              style={"width: #{PhoenixLiveSchedule.Utils.Safe.sanitize_css_dimension(@slot_width)}"}
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
            class="cal-timeline-resource-label flex-shrink-0 border-r border-base-200 px-2 py-2 flex items-center"
            style={"width: #{PhoenixLiveSchedule.Utils.Safe.sanitize_css_dimension(@resource_width)}"}
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
              style={"width: #{PhoenixLiveSchedule.Utils.Safe.sanitize_css_dimension(@slot_width)}; min-height: 3rem;"}
              phx-click={@on_slot_click}
              phx-value-resource-id={resource.id}
              phx-value-date={Date.to_iso8601(@date)}
              phx-value-time={Time.to_iso8601(slot)}
            >
            </div>

            <%!-- Positioned events for this resource --%>
            <div class="absolute inset-0 pointer-events-none py-0.5">
              <div
                :for={event <- Map.get(@events_by_resource, resource.id, [])}
                class="absolute top-0.5 bottom-0.5 pointer-events-auto z-10"
                style={timeline_event_style(event, @min_time, @max_time, @slots, @slot_width)}
              >
                <%= if @event != [] do %>
                  {render_slot(@event, event)}
                <% else %>
                  <EventItem.event_item
                    event={event}
                    on_click={@on_event_click}
                    class="h-full text-xs bg-primary/80 text-primary-content rounded px-1"
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

  defp timeline_event_style(event, min_time, max_time, _slots, _slot_width) do
    start_time = TimeSlots.to_time(event.start)
    end_time = TimeSlots.to_time(Event.effective_end(event))

    start_pct = TimeSlots.time_to_percentage(start_time, min_time: min_time, max_time: max_time)
    end_pct = TimeSlots.time_to_percentage(end_time, min_time: min_time, max_time: max_time)

    "left: #{start_pct}%; width: #{max(end_pct - start_pct, 2.0)}%"
  end
end
