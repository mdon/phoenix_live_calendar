defmodule PhoenixLiveCalendar.Components.MiniCalendar do
  @moduledoc """
  A compact month calendar used in year view and as a sidebar date picker.
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Utils.{DateHelpers, I18n}

  @doc """
  Renders a compact mini calendar for a given month.

  ## Attributes

  - `date` — A date within the target month
  - `selected_date` — Currently selected date (highlighted)
  - `today` — Today's date (for "today" indicator)
  - `events_by_date` — Map of `%{Date.t() => [Event.t()]}` for dot indicators
  - `markers_by_date` — Map of `%{Date.t() => [DayMarker.t()]}`; a marker's
    custom `color` tints the mini cell (heatmap intensity at year scale)
  - `on_date_click` — Event handler for date clicks
  - `week_start` — First day of week (1-7, default: 1)
  - `translations` — Translation overrides
  - `class` — Additional CSS classes
  - `show_header` — Show month/year header (default: true)
  """
  attr :date, Date, required: true
  attr :selected_date, Date, default: nil
  attr :today, Date, default: nil
  attr :events_by_date, :map, default: %{}
  attr :markers_by_date, :map, default: %{}
  attr :on_date_click, :any, default: nil
  attr :week_start, :integer, default: 1
  attr :translations, :map, default: %{}
  attr :class, :string, default: ""
  attr :show_header, :boolean, default: true

  def mini_calendar(assigns) do
    today = assigns.today || Date.utc_today()
    dates = DateHelpers.month_grid(assigns.date, week_start: assigns.week_start)
    weeks = DateHelpers.group_by_weeks(dates)
    day_names = I18n.ordered_day_names_narrow(assigns.week_start, assigns.translations)

    assigns =
      assigns
      |> assign(:today, today)
      |> assign(:weeks, weeks)
      |> assign(:day_names, day_names)

    ~H"""
    <div class={["cal-mini-calendar", @class]}>
      <div :if={@show_header} class="cal-mini-header text-center text-sm font-medium mb-1">
        {I18n.month_name_short(@date.month, @translations)} {@date.year}
      </div>

      <table
        class="cal-mini-grid w-full text-center text-xs"
        role="grid"
        aria-label={I18n.format_title(:month, @date, translations: @translations)}
      >
        <thead>
          <tr role="row">
            <th
              :for={name <- @day_names}
              class="cal-mini-day-header text-base-content/50 font-normal py-0.5"
              role="columnheader"
              scope="col"
            >
              {name}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={week <- @weeks} role="row">
            <td
              :for={date <- week}
              class={[
                "cal-mini-cell p-0.5",
                not DateHelpers.in_month?(date, @date) && "text-base-content/30",
                marker_color(Map.get(@markers_by_date, date, []))
              ]}
              role="gridcell"
              aria-selected={to_string(date == @selected_date)}
              aria-current={if(date == @today, do: "date")}
            >
              <button
                :if={@on_date_click}
                type="button"
                class={[
                  "cal-mini-date w-6 h-6 rounded-full text-xs leading-6 inline-block",
                  date == @today && "bg-primary text-primary-content font-bold",
                  date == @selected_date && date != @today && "bg-base-300 font-bold",
                  date != @today && date != @selected_date && "hover:bg-base-200"
                ]}
                phx-click={@on_date_click}
                phx-value-date={Date.to_iso8601(date)}
                tabindex={if(date == (@selected_date || @today), do: "0", else: "-1")}
              >
                {date.day}
              </button>
              <span
                :if={!@on_date_click}
                class={[
                  "cal-mini-date w-6 h-6 rounded-full text-xs leading-6 inline-block",
                  date == @today && "bg-primary text-primary-content font-bold"
                ]}
              >
                {date.day}
              </span>

              <div
                :if={Map.get(@events_by_date, date, []) != []}
                class="flex justify-center gap-0.5 -mt-0.5"
              >
                <div
                  :for={_event <- Enum.take(Map.get(@events_by_date, date, []), 3)}
                  class="w-1 h-1 rounded-full bg-primary"
                >
                </div>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  # First custom marker color for the date, plus a hook class. Type-based
  # tints are deliberately not rendered at mini scale — only explicit colors
  # (the heatmap case).
  defp marker_color(markers) do
    case Enum.find_value(markers, & &1.color) do
      nil -> nil
      color -> ["cal-mini-marked", color]
    end
  end
end
