defmodule PhoenixLiveSchedule.Components.TimeGutter do
  @moduledoc """
  Renders the time labels column alongside a time grid view.
  """

  use Phoenix.Component

  alias PhoenixLiveSchedule.Utils.{I18n, Safe, TimeSlots}

  @doc """
  Renders a vertical time gutter with hour labels.

  ## Attributes

  - `slots` — List of `Time` values for each slot (from `TimeSlots.time_grid_slots/1`)
  - `slot_height` — CSS height for each slot (default: "3rem")
  - `time_format` — `:h24` or `:h12` (default: `:h24`)
  - `secondary_timezone` — Optional secondary timezone label generator function
  - `class` — Additional CSS classes

  ## Slots

  - `time_label` — Custom time label rendering. Receives the time as slot argument.
  """
  attr :slots, :list, required: true
  attr :slot_height, :string, default: "3rem"
  attr :time_format, :atom, default: :h24
  attr :secondary_timezone, :any, default: nil
  attr :class, :string, default: ""

  slot :time_label

  def time_gutter(assigns) do
    ~H"""
    <div
      class={["cal-time-gutter flex flex-col flex-shrink-0 w-16 text-xs text-base-content/60", @class]}
      role="rowheader"
      aria-label="Time"
    >
      <div
        :for={time <- @slots}
        class="cal-time-slot border-b border-base-200 flex flex-col justify-start px-1 pt-0.5"
        style={"height: #{Safe.sanitize_css_dimension(@slot_height)}"}
      >
        <%= if @time_label != [] do %>
          {render_slot(@time_label, time)}
        <% else %>
          <span class="cal-time-primary">
            {I18n.format_time(time, format: @time_format)}
          </span>
          <span :if={@secondary_timezone} class="cal-time-secondary text-base-content/40">
            {@secondary_timezone.(time)}
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Renders a now indicator line positioned within the time grid.

  ## Attributes

  - `current_time` — Current `Time` value
  - `min_time` — Earliest visible time
  - `max_time` — Latest visible time
  - `class` — Additional CSS classes
  """
  attr :current_time, Time, required: true
  attr :min_time, Time, default: ~T[00:00:00]
  attr :max_time, Time, default: ~T[23:59:59]
  attr :class, :string, default: ""

  def now_indicator(assigns) do
    position =
      TimeSlots.time_to_percentage(assigns.current_time,
        min_time: assigns.min_time,
        max_time: assigns.max_time
      )

    assigns = assign(assigns, :position, position)

    ~H"""
    <div
      class={["cal-now-indicator absolute left-0 right-0 z-20 pointer-events-none", @class]}
      style={"top: #{@position}%"}
      aria-hidden="true"
    >
      <div class="flex items-center">
        <div class="w-2 h-2 rounded-full bg-error -ml-1"></div>
        <div class="flex-1 h-px bg-error"></div>
      </div>
    </div>
    """
  end
end
