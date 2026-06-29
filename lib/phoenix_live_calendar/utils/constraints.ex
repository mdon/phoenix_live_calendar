defmodule PhoenixLiveCalendar.Utils.Constraints do
  @moduledoc """
  Booking constraint validation logic.

  Pure Elixir functions for validating whether a proposed booking is allowed
  given a set of constraints, existing events, and availability windows.
  No database required — works with in-memory data.
  """

  alias PhoenixLiveCalendar.{Availability, BookingConfig, Event}

  @type validation_result :: :ok | {:error, reason :: atom(), message :: String.t()}

  @doc """
  Validates a proposed booking against all constraints.

  Returns `:ok` if the booking is valid, or `{:error, reason, message}` if not.

  ## Parameters

  - `start_dt` — Proposed start DateTime
  - `end_dt` — Proposed end DateTime
  - `config` — BookingConfig with constraints
  - `existing_events` — List of existing events to check for overlaps
  - `opts` — Additional options:
    - `now` — Current DateTime (default: `DateTime.utc_now()`)
    - `resource_id` — Resource to check availability against
    - `availabilities` — List of Availability windows

  ## Examples

      iex> Constraints.validate_booking(
      ...>   ~U[2026-04-01 10:00:00Z],
      ...>   ~U[2026-04-01 10:30:00Z],
      ...>   %BookingConfig{duration: 30, min_notice: 60},
      ...>   existing_events
      ...> )
      :ok

      iex> Constraints.validate_booking(
      ...>   ~U[2026-04-01 10:00:00Z],
      ...>   ~U[2026-04-01 10:15:00Z],
      ...>   %BookingConfig{duration: 30, min_duration: 30},
      ...>   []
      ...> )
      {:error, :too_short, "Booking must be at least 30 minutes"}
  """
  @spec validate_booking(DateTime.t(), DateTime.t(), BookingConfig.t(), [Event.t()], keyword()) ::
          validation_result()
  def validate_booking(start_dt, end_dt, %BookingConfig{} = config, existing_events, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    resource_id = Keyword.get(opts, :resource_id)
    availabilities = Keyword.get(opts, :availabilities, [])

    with :ok <- validate_time_order(start_dt, end_dt),
         :ok <- validate_duration(start_dt, end_dt, config),
         :ok <- validate_not_in_past(start_dt, now),
         :ok <- validate_min_notice(start_dt, now, config),
         :ok <- validate_max_advance(start_dt, now, config),
         :ok <- validate_availability(start_dt, end_dt, availabilities, resource_id),
         :ok <- validate_no_overlap(start_dt, end_dt, config, existing_events) do
      validate_capacity(start_dt, end_dt, config, existing_events)
    end
  end

  @doc """
  Checks if a proposed time range overlaps with any existing events.

  Accounts for buffer times defined in the config.
  """
  @spec has_overlap?(DateTime.t(), DateTime.t(), BookingConfig.t(), [Event.t()]) :: boolean()
  def has_overlap?(start_dt, end_dt, %BookingConfig{} = config, events) do
    buffered_start = DateTime.add(start_dt, -(config.buffer_before * 60), :second)
    buffered_end = DateTime.add(end_dt, config.buffer_after * 60, :second)

    Enum.any?(events, fn event ->
      not Event.all_day?(event) and
        events_overlap?(buffered_start, buffered_end, event)
    end)
  end

  @doc """
  Counts how many bookings overlap with a given time range.

  Used for capacity/seat checking.
  """
  @spec overlap_count(DateTime.t(), DateTime.t(), [Event.t()]) :: non_neg_integer()
  def overlap_count(start_dt, end_dt, events) do
    Enum.count(events, fn event ->
      not Event.all_day?(event) and events_overlap?(start_dt, end_dt, event)
    end)
  end

  @doc """
  Returns all events that conflict with a proposed time range.
  """
  @spec conflicting_events(DateTime.t(), DateTime.t(), [Event.t()]) :: [Event.t()]
  def conflicting_events(start_dt, end_dt, events) do
    Enum.filter(events, fn event ->
      not Event.all_day?(event) and events_overlap?(start_dt, end_dt, event)
    end)
  end

  @doc """
  Snaps a time to the nearest slot boundary based on the slot interval.

  ## Examples

      iex> Constraints.snap_to_slot(~T[10:17:00], 15)
      ~T[10:15:00]

      iex> Constraints.snap_to_slot(~T[10:23:00], 15)
      ~T[10:15:00]

      iex> Constraints.snap_to_slot(~T[10:38:00], 15)
      ~T[10:30:00]
  """
  @spec snap_to_slot(Time.t(), pos_integer()) :: Time.t()
  def snap_to_slot(%Time{} = time, slot_minutes) do
    total_minutes = time.hour * 60 + time.minute
    snapped = div(total_minutes, slot_minutes) * slot_minutes
    Time.new!(div(snapped, 60), rem(snapped, 60), 0)
  end

  @doc """
  Snaps a DateTime to the nearest slot boundary.
  """
  @spec snap_datetime_to_slot(DateTime.t(), pos_integer()) :: DateTime.t()
  def snap_datetime_to_slot(%DateTime{} = dt, slot_minutes) do
    snapped_time = snap_to_slot(DateTime.to_time(dt), slot_minutes)
    date = DateTime.to_date(dt)
    {:ok, ndt} = NaiveDateTime.new(date, snapped_time)

    # Fall back to UTC if timezone database doesn't support the timezone
    case DateTime.from_naive(ndt, dt.time_zone) do
      {:ok, result} -> result
      {:error, _} -> DateTime.from_naive!(ndt, "Etc/UTC")
    end
  end

  # -- Private validation functions --

  defp validate_time_order(start_dt, end_dt) do
    if DateTime.compare(start_dt, end_dt) == :lt do
      :ok
    else
      {:error, :invalid_range, "Start time must be before end time"}
    end
  end

  defp validate_duration(start_dt, end_dt, config) do
    duration_minutes = div(DateTime.diff(end_dt, start_dt, :second), 60)
    min_dur = BookingConfig.effective_min_duration(config)
    max_dur = BookingConfig.effective_max_duration(config)

    cond do
      duration_minutes < min_dur ->
        {:error, :too_short, "Booking must be at least #{min_dur} minutes"}

      duration_minutes > max_dur ->
        {:error, :too_long, "Booking cannot exceed #{max_dur} minutes"}

      true ->
        :ok
    end
  end

  defp validate_not_in_past(start_dt, now) do
    if DateTime.compare(start_dt, now) != :lt do
      :ok
    else
      {:error, :in_past, "Cannot book in the past"}
    end
  end

  defp validate_min_notice(_start_dt, _now, %BookingConfig{min_notice: 0}), do: :ok

  defp validate_min_notice(start_dt, now, config) do
    earliest_allowed = DateTime.add(now, config.min_notice * 60, :second)

    if DateTime.compare(start_dt, earliest_allowed) != :lt do
      :ok
    else
      {:error, :insufficient_notice,
       "Booking requires at least #{config.min_notice} minutes advance notice"}
    end
  end

  defp validate_max_advance(_start_dt, _now, %BookingConfig{max_advance: nil}), do: :ok

  defp validate_max_advance(start_dt, now, config) do
    latest_date = Date.add(DateTime.to_date(now), config.max_advance)
    booking_date = DateTime.to_date(start_dt)

    if Date.compare(booking_date, latest_date) != :gt do
      :ok
    else
      {:error, :too_far_ahead, "Cannot book more than #{config.max_advance} days in advance"}
    end
  end

  defp validate_availability(_start_dt, _end_dt, [], _resource_id), do: :ok

  defp validate_availability(start_dt, end_dt, availabilities, resource_id) do
    date = DateTime.to_date(start_dt)
    start_time = DateTime.to_time(start_dt)
    end_time = DateTime.to_time(end_dt)

    windows = Availability.windows_for_date(availabilities, date, resource_id)

    # Check that the entire booking falls within an available window
    covered =
      Enum.any?(windows, fn w ->
        w.available and
          Time.compare(start_time, w.start_time) != :lt and
          Time.compare(end_time, w.end_time) != :gt
      end)

    if covered do
      :ok
    else
      {:error, :outside_availability, "Booking falls outside available hours"}
    end
  end

  defp validate_no_overlap(start_dt, end_dt, config, events) do
    # Only check events that don't allow overlap (overlap: false)
    blocking_events = Enum.reject(events, & &1.overlap)

    if has_overlap?(start_dt, end_dt, config, blocking_events) do
      {:error, :overlap, "Booking conflicts with an existing event"}
    else
      :ok
    end
  end

  defp validate_capacity(start_dt, end_dt, %BookingConfig{seats: seats}, events) when seats > 1 do
    count = overlap_count(start_dt, end_dt, events)

    if count < seats do
      :ok
    else
      {:error, :at_capacity, "This time slot is fully booked (#{seats} seats)"}
    end
  end

  defp validate_capacity(_start_dt, _end_dt, _config, _events), do: :ok

  defp events_overlap?(range_start, range_end, event) do
    event_start = event.start
    event_end = Event.effective_end(event)

    compare_dt(event_start, range_end) == :lt and
      compare_dt(event_end, range_start) == :gt
  end

  defp compare_dt(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b)

  defp compare_dt(%NaiveDateTime{} = a, %DateTime{} = b),
    do: DateTime.compare(DateTime.from_naive!(a, "Etc/UTC"), b)

  defp compare_dt(%DateTime{} = a, %NaiveDateTime{} = b),
    do: DateTime.compare(a, DateTime.from_naive!(b, "Etc/UTC"))

  defp compare_dt(%NaiveDateTime{} = a, %NaiveDateTime{} = b),
    do: NaiveDateTime.compare(a, b)

  defp compare_dt(%Date{} = a, b),
    do: compare_dt(DateTime.from_naive!(NaiveDateTime.new!(a, ~T[00:00:00]), "Etc/UTC"), b)

  defp compare_dt(a, %Date{} = b),
    do: compare_dt(a, DateTime.from_naive!(NaiveDateTime.new!(b, ~T[00:00:00]), "Etc/UTC"))
end
