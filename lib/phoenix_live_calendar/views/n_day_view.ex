defmodule PhoenixLiveCalendar.Views.NDayView do
  @moduledoc """
  N-day view — shows an arbitrary number of day columns.

  This is the flexible view that handles 3-day, 4-day, 10-day, or any
  custom day count. Uses `WeekGrid` internally with computed dates.
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Utils.DateHelpers
  alias PhoenixLiveCalendar.Views.WeekGrid

  @doc """
  Renders an N-day time grid view.

  ## Attributes

  - `date` — Start date of the view
  - `days` — Number of days to display
  - All other attributes are passed through to `WeekGrid.week_grid/1`
  """
  attr :date, Date, required: true
  attr :id, :string, default: nil
  attr :days, :integer, required: true
  attr :events, :list, default: []
  attr :selected_date, Date, default: nil
  attr :today, Date, default: nil
  attr :min_time, Time, default: ~T[00:00:00]
  attr :max_time, Time, default: ~T[23:59:59]
  attr :slot_duration, :integer, default: 30
  attr :slot_height, :string, default: "3rem"
  attr :show_now_indicator, :boolean, default: true
  attr :now, Time, default: nil
  attr :show_all_day_row, :boolean, default: true
  attr :business_hours, :list, default: []
  attr :day_markers, :list, default: []
  attr :event_detail, :boolean, default: true
  attr :on_date_click, :any, default: nil
  attr :on_time_click, :any, default: nil
  attr :on_event_click, :any, default: nil
  attr :translations, :map, default: %{}
  attr :time_format, :atom, default: :h24
  attr :class, :string, default: ""
  attr :dir, :atom, default: :ltr

  slot :event
  slot :time_label

  def n_day_view(assigns) do
    dates = DateHelpers.n_day_dates(assigns.date, assigns.days)
    assigns = assign(assigns, :dates, dates)

    ~H"""
    <WeekGrid.week_grid
      id={@id}
      dates={@dates}
      events={@events}
      selected_date={@selected_date}
      today={@today}
      min_time={@min_time}
      max_time={@max_time}
      slot_duration={@slot_duration}
      slot_height={@slot_height}
      show_now_indicator={@show_now_indicator}
      now={@now}
      show_all_day_row={@show_all_day_row}
      business_hours={@business_hours}
      day_markers={@day_markers}
      event_detail={@event_detail}
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
