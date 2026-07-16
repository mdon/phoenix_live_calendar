defmodule PhoenixLiveCalendar.DayMarker do
  @moduledoc """
  Represents a date-level annotation — holidays, special hours, closures, notices.

  Day markers are **not events**. They annotate the date itself rather than
  occupying a time slot. They appear as visual indicators on the day cell
  (background color, label, icon) and can span multiple days.

  Use day markers for:
  - Public holidays ("Christmas Day", "New Year")
  - Special operating hours ("Winter hours: 10am-3pm")
  - Office closures ("Office closed for renovation")
  - Seasonal notices ("Peak season — limited availability")
  - Custom date labels ("Payday", "Sprint 12 start")

  Day markers can optionally override availability — e.g., a holiday marker
  with `available: false` blocks booking, while a "reduced hours" marker with
  custom `availability` windows allows booking within those reduced hours.

  ## Examples

      # Public holiday — fully closed
      %DayMarker{
        id: "xmas",
        label: "Christmas Day",
        start_date: ~D[2026-12-25],
        end_date: ~D[2026-12-26],
        type: :holiday,
        color: "bg-error/20",
        icon: "🎄",
        available: false
      }

      # Reduced hours — bookable within modified schedule
      %DayMarker{
        id: "winter-hours",
        label: "Winter Hours",
        start_date: ~D[2026-12-20],
        end_date: ~D[2027-01-05],
        type: :notice,
        color: "bg-info/10",
        description: "Reduced hours: 10am-3pm",
        availability: [
          %PhoenixLiveCalendar.Availability{
            days_of_week: [1, 2, 3, 4, 5],
            start_time: ~T[10:00:00],
            end_time: ~T[15:00:00]
          }
        ]
      }

      # Simple label
      %DayMarker{
        id: "payday",
        label: "Payday",
        start_date: ~D[2026-04-15],
        type: :label,
        color: "bg-success/10"
      }

      # Heatmap tint — cell background only, no corner label chip
      %DayMarker{
        id: "activity-2026-04-15",
        label: "42 minutes",
        start_date: ~D[2026-04-15],
        color: "bg-success/30",
        show_label: false
      }

  ## Styling

  - `color` — cell background class. When set, it becomes the day cell's
    background (winning over the weekend/out-of-month tint; today/selected
    stay visible via an inset ring). When unset, the cell falls back to the
    type-based tint (`:holiday`/`:closure`/`:notice`/`:season`).
  - `text_color` / `class` — applied to the corner label chip instead of the
    type-based chip colors. `class` is the chip background/extra classes,
    `text_color` the text class.
  - `show_label` — set `false` (or `label: nil`) to render only the cell
    tint with no corner chip; ideal for heatmap-style markers.

  All classes are the consumer's responsibility to make Tailwind-visible
  (complete class names, no interpolation).
  """

  @enforce_keys [:id, :label, :start_date]
  defstruct [
    :id,
    :label,
    :start_date,
    :end_date,
    :description,
    :icon,
    :color,
    :text_color,
    :class,
    :availability,
    type: :notice,
    available: true,
    show_label: true,
    extra: %{}
  ]

  @type marker_type :: :holiday | :closure | :notice | :label | :season | :custom
  @type t :: %__MODULE__{
          id: term(),
          label: String.t(),
          start_date: Date.t(),
          end_date: Date.t() | nil,
          description: String.t() | nil,
          icon: String.t() | nil,
          color: String.t() | nil,
          text_color: String.t() | nil,
          class: String.t() | nil,
          availability: [PhoenixLiveCalendar.Availability.t()] | nil,
          type: marker_type(),
          available: boolean(),
          show_label: boolean(),
          extra: map()
        }

  @doc """
  Returns the effective end date (exclusive). Defaults to start + 1 day.
  """
  @spec effective_end_date(t()) :: Date.t()
  def effective_end_date(%__MODULE__{end_date: nil, start_date: start}), do: Date.add(start, 1)
  def effective_end_date(%__MODULE__{end_date: end_date}), do: end_date

  @doc """
  Returns whether this marker covers the given date.
  """
  @spec covers_date?(t(), Date.t()) :: boolean()
  def covers_date?(%__MODULE__{} = marker, %Date{} = date) do
    Date.compare(marker.start_date, date) != :gt and
      Date.compare(effective_end_date(marker), date) == :gt
  end

  @doc """
  Returns the number of days this marker spans.
  """
  @spec span_days(t()) :: pos_integer()
  def span_days(%__MODULE__{} = marker) do
    Date.diff(effective_end_date(marker), marker.start_date)
  end

  @doc """
  Returns all markers that cover a given date from a list.
  """
  @spec markers_for_date([t()], Date.t()) :: [t()]
  def markers_for_date(markers, %Date{} = date) do
    Enum.filter(markers, &covers_date?(&1, date))
  end

  @doc """
  Groups markers by date for a list of dates. Returns `%{Date.t() => [t()]}`.
  """
  @spec group_by_date([t()], [Date.t()]) :: %{Date.t() => [t()]}
  def group_by_date(markers, dates) do
    base = Map.new(dates, &{&1, []})

    Enum.reduce(markers, base, fn marker, acc ->
      Enum.reduce(dates, acc, &put_marker_on_date(marker, &1, &2))
    end)
  end

  defp put_marker_on_date(marker, date, acc) do
    if covers_date?(marker, date) do
      Map.update!(acc, date, &[marker | &1])
    else
      acc
    end
  end

  # -- Shared styling helpers (used by the month, week, day and year views) --

  @doc """
  The first custom cell `color` among a day's markers, or `nil`.
  """
  @spec custom_color([t()]) :: String.t() | nil
  def custom_color(markers) do
    Enum.find_value(markers, fn marker -> PhoenixLiveCalendar.Theme.bg(marker.color) end)
  end

  @doc """
  The semantic hook class for a day's markers (`cal-day-holiday` /
  `cal-day-closed` / `cal-day-notice` / `cal-day-season`), or `nil`.
  Kept on the cell even when a custom color replaces the tint, so consumer
  CSS/tests keying off it keep matching.
  """
  @spec semantic_class([t()]) :: String.t() | nil
  def semantic_class(markers) do
    cond do
      Enum.any?(markers, &(not &1.available and &1.type == :holiday)) -> "cal-day-holiday"
      Enum.any?(markers, &(not &1.available)) -> "cal-day-closed"
      Enum.any?(markers, &(&1.type == :notice)) -> "cal-day-notice"
      Enum.any?(markers, &(&1.type == :season)) -> "cal-day-season"
      true -> nil
    end
  end

  @doc """
  The type-based background tint for a day's markers, or `nil`.
  """
  @spec type_tint([t()]) :: String.t() | nil
  def type_tint(markers) do
    case semantic_class(markers) do
      "cal-day-holiday" -> "bg-error/8"
      "cal-day-closed" -> "bg-error/5"
      "cal-day-notice" -> "bg-info/5"
      "cal-day-season" -> "bg-accent/5"
      nil -> nil
    end
  end

  @doc """
  The classes for a marker's label chip: its own `class`/`text_color` when
  either is set, else the type-based defaults.
  """
  @spec chip_class(t()) :: [String.t() | nil] | String.t()
  def chip_class(%{class: class, text_color: text_color})
      when not is_nil(class) or not is_nil(text_color) do
    [class, text_color]
  end

  def chip_class(%{type: :holiday}), do: "bg-error/30 text-error-content"
  def chip_class(%{type: :closure}), do: "bg-warning/30 text-warning-content"
  def chip_class(%{type: :notice}), do: "bg-info/20 text-info"
  def chip_class(%{type: :label}), do: "bg-success/20 text-success"
  def chip_class(%{type: :season}), do: "bg-accent/20 text-accent"
  def chip_class(_marker), do: "bg-base-200 text-base-content/60"

  @doc """
  Markers that want a visible label chip (`show_label` and a non-nil label).
  """
  @spec labeled([t()]) :: [t()]
  def labeled(markers) do
    Enum.filter(markers, &(&1.show_label and &1.label != nil))
  end
end
