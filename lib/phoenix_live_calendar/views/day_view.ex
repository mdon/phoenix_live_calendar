defmodule PhoenixLiveCalendar.Views.DayView do
  @moduledoc """
  Day view — a single-column time grid. Delegates to `WeekGrid` with one date.
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Views.WeekGrid

  @doc """
  Renders a single-day time grid view.

  Accepts the same attributes as `WeekGrid.week_grid/1`, but takes a single
  `date` instead of a `dates` list.
  """
  attr :date, Date, required: true
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

  def day_view(assigns) do
    assigns = assign(assigns, :dates, [assigns.date])

    ~H"""
    <WeekGrid.week_grid
      dates={@dates}
      events={@events}
      selected_date={@selected_date}
      today={@today}
      min_time={@min_time}
      max_time={@max_time}
      slot_duration={@slot_duration}
      slot_height={@slot_height}
      show_now_indicator={@show_now_indicator}
      show_all_day_row={@show_all_day_row}
      business_hours={@business_hours}
      on_date_click={@on_date_click}
      on_time_click={@on_time_click}
      on_event_click={@on_event_click}
      translations={@translations}
      time_format={@time_format}
      class={@class}
      dir={@dir}
    >
      <:event :let={event} :if={@event != []}>
        {render_slot(@event, event)}
      </:event>
      <:time_label :let={time} :if={@time_label != []}>
        {render_slot(@time_label, time)}
      </:time_label>
    </WeekGrid.week_grid>
    """
  end
end
