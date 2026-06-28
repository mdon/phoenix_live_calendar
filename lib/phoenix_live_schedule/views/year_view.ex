defmodule PhoenixLiveSchedule.Views.YearView do
  @moduledoc """
  Year view — displays 12 mini-month calendars in a responsive grid.

  Uses lightweight rendering: event dots only, no event details.
  Click a date to navigate to that day's detail view.
  """

  use Phoenix.Component

  alias PhoenixLiveSchedule.Components.MiniCalendar
  alias PhoenixLiveSchedule.Utils.{DateHelpers, I18n}

  @doc """
  Renders a year view with 12 mini-month calendars.

  ## Attributes

  - `year` — The year to display
  - `events` — List of `PhoenixLiveSchedule.Event` structs (used for dot indicators)
  - `selected_date` — Currently selected date
  - `today` — Today's date
  - `week_start` — First day of week (default: 1)
  - `columns` — Number of columns in the grid (default: 3)
  - `on_date_click` — Handler for date clicks
  - `translations` — Translation overrides
  - `class` — Additional CSS classes
  """
  attr :year, :integer, required: true
  attr :events, :list, default: []
  attr :selected_date, Date, default: nil
  attr :today, Date, default: nil
  attr :week_start, :integer, default: 1
  attr :columns, :integer, default: 3
  attr :on_date_click, :any, default: nil
  attr :translations, :map, default: %{}
  attr :class, :string, default: ""

  def year_view(assigns) do
    today = assigns.today || Date.utc_today()

    months =
      Enum.map(1..12, fn month ->
        date = Date.new!(assigns.year, month, 1)
        grid_dates = DateHelpers.month_grid(date, week_start: assigns.week_start)
        events_by_date = DateHelpers.group_events_by_date(assigns.events, grid_dates)
        {date, events_by_date}
      end)

    assigns =
      assigns
      |> assign(:today, today)
      |> assign(:months, months)

    ~H"""
    <div
      class={[
        "cal-year-view grid gap-4 p-2",
        grid_cols_class(@columns),
        @class
      ]}
      role="grid"
      aria-label={I18n.format_title(:year, Date.new!(@year, 1, 1))}
    >
      <div :for={{date, events_by_date} <- @months} class="cal-year-month">
        <MiniCalendar.mini_calendar
          date={date}
          selected_date={@selected_date}
          today={@today}
          events_by_date={events_by_date}
          on_date_click={@on_date_click}
          week_start={@week_start}
          translations={@translations}
        />
      </div>
    </div>
    """
  end

  defp grid_cols_class(1), do: "grid-cols-1"
  defp grid_cols_class(2), do: "grid-cols-2"
  defp grid_cols_class(3), do: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
  defp grid_cols_class(4), do: "grid-cols-2 lg:grid-cols-4"
  defp grid_cols_class(6), do: "grid-cols-2 md:grid-cols-3 lg:grid-cols-6"
  defp grid_cols_class(_), do: "grid-cols-3"
end
