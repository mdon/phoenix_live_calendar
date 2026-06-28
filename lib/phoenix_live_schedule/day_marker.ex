defmodule PhoenixLiveSchedule.DayMarker do
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
          %PhoenixLiveSchedule.Availability{
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
          availability: [PhoenixLiveSchedule.Availability.t()] | nil,
          type: marker_type(),
          available: boolean(),
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
      Enum.reduce(dates, acc, fn date, inner_acc ->
        if covers_date?(marker, date) do
          Map.update!(inner_acc, date, &[marker | &1])
        else
          inner_acc
        end
      end)
    end)
  end
end
