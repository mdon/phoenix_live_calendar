defmodule PhoenixLiveSchedule.Availability do
  @moduledoc """
  Represents a recurring availability window or a date-specific override.

  Used to define when time slots are bookable (business hours, working hours,
  provider availability, etc.).

  ## Recurring availability (day-of-week based)

      # Monday through Friday, 9am to 5pm
      %PhoenixLiveSchedule.Availability{
        days_of_week: [1, 2, 3, 4, 5],
        start_time: ~T[09:00:00],
        end_time: ~T[17:00:00]
      }

  ## Date-specific override

      # Special hours on a specific date
      %PhoenixLiveSchedule.Availability{
        date: ~D[2026-04-15],
        start_time: ~T[10:00:00],
        end_time: ~T[14:00:00]
      }

      # Block out a specific date entirely
      %PhoenixLiveSchedule.Availability{
        date: ~D[2026-04-20],
        start_time: ~T[00:00:00],
        end_time: ~T[23:59:59],
        available: false
      }

  ## Per-resource availability

      # Dr. Smith is available Mon/Wed/Fri mornings
      %PhoenixLiveSchedule.Availability{
        days_of_week: [1, 3, 5],
        start_time: ~T[08:00:00],
        end_time: ~T[12:00:00],
        resource_id: "dr-smith"
      }

  ## Day numbering

  Days of week use ISO numbering: 1 = Monday, 7 = Sunday.
  """

  defstruct [
    :days_of_week,
    :date,
    :start_time,
    :end_time,
    :resource_id,
    available: true
  ]

  # Note: this struct ordering is valid because `available: true`
  # is the only keyword field and it comes last.

  @type t :: %__MODULE__{
          days_of_week: [1..7] | nil,
          date: Date.t() | nil,
          start_time: Time.t(),
          end_time: Time.t(),
          resource_id: term() | nil,
          available: boolean()
        }

  @doc """
  Returns whether this availability applies on the given date.

  Date-specific overrides match by exact date. Recurring availability
  matches by day of week.
  """
  @spec applies_on?(t(), Date.t()) :: boolean()
  def applies_on?(%__MODULE__{date: date}, %Date{} = target) when not is_nil(date) do
    Date.compare(date, target) == :eq
  end

  def applies_on?(%__MODULE__{days_of_week: days}, %Date{} = target) when is_list(days) do
    Date.day_of_week(target) in days
  end

  def applies_on?(%__MODULE__{}, %Date{}), do: false

  @doc """
  Returns whether the given time falls within this availability window.
  """
  @spec covers_time?(t(), Time.t()) :: boolean()
  def covers_time?(%__MODULE__{start_time: start_time, end_time: end_time}, %Time{} = time) do
    Time.compare(time, start_time) != :lt and Time.compare(time, end_time) == :lt
  end

  @doc """
  Returns the effective availability windows for a given date from a list of availabilities.

  Date-specific overrides take precedence over recurring day-of-week patterns.
  Returns only the windows that apply, sorted by start time.
  """
  @spec windows_for_date([t()], Date.t(), term() | nil) :: [t()]
  def windows_for_date(availabilities, %Date{} = date, resource_id \\ nil) do
    # Filter by resource
    scoped =
      Enum.filter(availabilities, fn a ->
        a.resource_id == resource_id or a.resource_id == nil
      end)

    # Check for date-specific overrides first
    date_overrides = Enum.filter(scoped, &(not is_nil(&1.date) and applies_on?(&1, date)))

    windows =
      if date_overrides != [] do
        date_overrides
      else
        Enum.filter(scoped, &(is_nil(&1.date) and applies_on?(&1, date)))
      end

    Enum.sort_by(windows, & &1.start_time, Time)
  end
end
