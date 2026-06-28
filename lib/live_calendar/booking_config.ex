defmodule LiveCalendar.BookingConfig do
  @moduledoc """
  Defines constraints for bookable time slots.

  This is not an event — it's a template that defines the rules for creating events
  (like Cal.com's Event Types or a clinic's appointment type configuration).

  ## Examples

      # Standard 30-minute meetings with 5-minute buffer
      %LiveCalendar.BookingConfig{
        duration: 30,
        buffer_after: 5,
        min_notice: 60,
        max_advance: 30
      }

      # Flexible duration consultation (15-60 min)
      %LiveCalendar.BookingConfig{
        duration: 30,
        min_duration: 15,
        max_duration: 60,
        slot_interval: 15,
        buffer_before: 10,
        buffer_after: 10
      }

      # Group class with capacity
      %LiveCalendar.BookingConfig{
        duration: 60,
        seats: 20,
        min_notice: 120,
        availability: [
          %LiveCalendar.Availability{
            days_of_week: [1, 3, 5],
            start_time: ~T[09:00:00],
            end_time: ~T[10:00:00]
          }
        ]
      }

  ## Fields

  - `duration` — Default slot duration in minutes (default: 30)
  - `min_duration` / `max_duration` — Allowed range for free-form booking
  - `slot_interval` — Minutes between slot start times. If nil, defaults to `duration`.
    Example: duration=60, slot_interval=15 means slots at 9:00, 9:15, 9:30, 9:45, 10:00...
  - `buffer_before` / `buffer_after` — Required gap in minutes before/after each booking
  - `min_notice` — Minimum minutes in advance a booking can be made (0 = no restriction)
  - `max_advance` — Maximum days in advance a booking can be made (nil = no limit)
  - `seats` — Number of concurrent bookings per slot (1 = exclusive, >1 = group/shared)
  - `availability` — List of `LiveCalendar.Availability` windows when slots are offered
  - `timezone` — IANA timezone string for interpreting availability times
  """

  defstruct [
    :min_duration,
    :max_duration,
    :slot_interval,
    :max_advance,
    :timezone,
    duration: 30,
    buffer_before: 0,
    buffer_after: 0,
    min_notice: 0,
    seats: 1,
    availability: []
  ]

  @type t :: %__MODULE__{
          duration: pos_integer(),
          min_duration: pos_integer() | nil,
          max_duration: pos_integer() | nil,
          slot_interval: pos_integer() | nil,
          buffer_before: non_neg_integer(),
          buffer_after: non_neg_integer(),
          min_notice: non_neg_integer(),
          max_advance: pos_integer() | nil,
          seats: pos_integer(),
          availability: [LiveCalendar.Availability.t()] | nil,
          timezone: String.t() | nil
        }

  @doc """
  Returns the effective slot interval in minutes.

  If `slot_interval` is nil, falls back to `duration`.
  """
  @spec effective_slot_interval(t()) :: pos_integer()
  def effective_slot_interval(%__MODULE__{slot_interval: nil, duration: d}), do: d
  def effective_slot_interval(%__MODULE__{slot_interval: si}), do: si

  @doc """
  Returns the effective min duration in minutes.
  """
  @spec effective_min_duration(t()) :: pos_integer()
  def effective_min_duration(%__MODULE__{min_duration: nil, duration: d}), do: d
  def effective_min_duration(%__MODULE__{min_duration: min}), do: min

  @doc """
  Returns the effective max duration in minutes.
  """
  @spec effective_max_duration(t()) :: pos_integer()
  def effective_max_duration(%__MODULE__{max_duration: nil, duration: d}), do: d
  def effective_max_duration(%__MODULE__{max_duration: max}), do: max

  @doc """
  Returns the total blocked time around a booking in minutes (buffer_before + duration + buffer_after).
  """
  @spec total_blocked_time(t()) :: pos_integer()
  def total_blocked_time(%__MODULE__{} = config) do
    config.buffer_before + config.duration + config.buffer_after
  end
end
