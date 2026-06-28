defmodule PhoenixLiveSchedule.Utils.TimeSlots do
  @moduledoc """
  Generates time slot grids for day/week views and bookable slot lists.

  Handles slot generation based on duration, availability windows, and
  booking configurations.
  """

  require Logger

  alias PhoenixLiveSchedule.{Availability, BookingConfig}

  @doc """
  Generates time slot boundaries for a time grid view.

  Returns a list of `Time` values representing the start of each slot.

  ## Options

  - `min_time` — Earliest time to show (default: `~T[00:00:00]`)
  - `max_time` — Latest time to show (default: `~T[24:00:00]`, represented as `~T[23:59:59]`)
  - `slot_duration` — Duration of each slot in minutes (default: 30)

  ## Examples

      iex> TimeSlots.time_grid_slots(min_time: ~T[09:00:00], max_time: ~T[17:00:00], slot_duration: 60)
      [~T[09:00:00], ~T[10:00:00], ~T[11:00:00], ~T[12:00:00],
       ~T[13:00:00], ~T[14:00:00], ~T[15:00:00], ~T[16:00:00]]
  """
  @spec time_grid_slots(keyword()) :: [Time.t()]
  def time_grid_slots(opts \\ []) do
    min_time = Keyword.get(opts, :min_time, ~T[00:00:00])
    max_time = Keyword.get(opts, :max_time, ~T[23:59:59])
    slot_duration = Keyword.get(opts, :slot_duration, 30)

    generate_time_slots(min_time, max_time, slot_duration)
  end

  @doc """
  Generates bookable time slots for a specific date given a booking configuration.

  Takes existing events into account for overlap detection. Returns a list
  of `{start_time, end_time, status}` tuples where status is `:available`,
  `:unavailable`, or `:booked`.

  ## Examples

      config = %BookingConfig{duration: 30, slot_interval: 30, buffer_after: 5}
      availability = [%Availability{days_of_week: [1,2,3,4,5], start_time: ~T[09:00:00], end_time: ~T[17:00:00]}]
      existing_events = [...]

      TimeSlots.bookable_slots(~D[2026-04-01], config, availability, existing_events)
      # => [{~T[09:00:00], ~T[09:30:00], :available},
      #     {~T[09:30:00], ~T[10:00:00], :booked},
      #     {~T[10:00:00], ~T[10:30:00], :available}, ...]
  """
  @spec bookable_slots(Date.t(), BookingConfig.t(), [Availability.t()], [
          PhoenixLiveSchedule.Event.t()
        ]) :: [{Time.t(), Time.t(), :available | :unavailable | :booked}]
  def bookable_slots(%Date{} = date, %BookingConfig{} = config, availabilities, events \\ []) do
    windows = Availability.windows_for_date(availabilities, date)
    interval = BookingConfig.effective_slot_interval(config)
    duration = config.duration

    # Generate all possible slots within availability windows
    available_slots =
      Enum.flat_map(windows, fn window ->
        if window.available do
          slots_for_window(window, interval, duration)
        else
          []
        end
      end)

    # Check each slot against existing events and constraints
    now = DateTime.utc_now()

    Enum.map(available_slots, fn {start_time, end_time} ->
      status = slot_status(date, start_time, end_time, config, events, now)
      {start_time, end_time, status}
    end)
  end

  @doc """
  Returns the vertical position (as a percentage) of a time within the day grid.

  Useful for absolutely positioning events in a time grid view.

  ## Options

  - `min_time` — Earliest visible time (default: `~T[00:00:00]`)
  - `max_time` — Latest visible time (default: `~T[24:00:00]`)

  ## Examples

      iex> TimeSlots.time_to_percentage(~T[12:00:00])
      50.0

      iex> TimeSlots.time_to_percentage(~T[12:00:00], min_time: ~T[08:00:00], max_time: ~T[20:00:00])
      33.33
  """
  @spec time_to_percentage(Time.t(), keyword()) :: float()
  def time_to_percentage(%Time{} = time, opts \\ []) do
    min_time = Keyword.get(opts, :min_time, ~T[00:00:00])
    max_time = Keyword.get(opts, :max_time, ~T[23:59:59])

    min_seconds = time_to_seconds(min_time)
    max_seconds = time_to_seconds(max_time)
    current_seconds = time_to_seconds(time)

    total_range = max_seconds - min_seconds

    if total_range > 0 do
      ((current_seconds - min_seconds) / total_range * 100)
      |> Float.round(2)
      |> max(0.0)
      |> min(100.0)
    else
      0.0
    end
  end

  @doc """
  Returns the height (as a percentage) for an event duration in the time grid.
  """
  @spec duration_to_percentage(Time.t(), Time.t(), keyword()) :: float()
  def duration_to_percentage(%Time{} = start_time, %Time{} = end_time, opts \\ []) do
    time_to_percentage(end_time, opts) - time_to_percentage(start_time, opts)
  end

  @doc """
  Extracts the time component from a DateTime or NaiveDateTime.
  Returns the value unchanged if already a Time.
  """
  @spec to_time(DateTime.t() | NaiveDateTime.t() | Time.t()) :: Time.t()
  def to_time(%Time{} = t), do: t
  def to_time(%DateTime{} = dt), do: DateTime.to_time(dt)
  def to_time(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_time(ndt)

  # -- Private --

  defp slots_for_window(window, interval, duration) do
    generate_time_slots(window.start_time, window.end_time, interval)
    |> Enum.map(fn start_time ->
      end_time = Time.add(start_time, duration * 60, :second)
      {start_time, end_time}
    end)
    |> Enum.filter(fn {_start, end_time} ->
      # Ensure slot end doesn't exceed the window
      Time.compare(end_time, window.end_time) != :gt
    end)
  end

  defp generate_time_slots(min_time, max_time, slot_duration_minutes) do
    slot_seconds = slot_duration_minutes * 60
    min_seconds = time_to_seconds(min_time)
    max_seconds = time_to_seconds(max_time)

    Stream.iterate(min_seconds, &(&1 + slot_seconds))
    |> Enum.take_while(&(&1 < max_seconds))
    |> Enum.map(&seconds_to_time/1)
  end

  defp slot_status(date, start_time, _end_time, config, events, now) do
    slot_dt = datetime_from_date_time(date, start_time)

    cond do
      # Check minimum notice
      config.min_notice > 0 and
          DateTime.compare(slot_dt, DateTime.add(now, config.min_notice * 60, :second)) == :lt ->
        :unavailable

      # Check maximum advance
      config.max_advance != nil and
          Date.compare(date, Date.add(DateTime.to_date(now), config.max_advance)) == :gt ->
        :unavailable

      # Check overlap with existing events
      true ->
        slot_end_dt = DateTime.add(slot_dt, config.duration * 60, :second)
        buffered_start = DateTime.add(slot_dt, -(config.buffer_before * 60), :second)
        buffered_end = DateTime.add(slot_end_dt, config.buffer_after * 60, :second)

        booked_count =
          Enum.count(events, fn event ->
            not PhoenixLiveSchedule.Event.all_day?(event) and
              compare_dt(event.start, buffered_end) == :lt and
              compare_dt(PhoenixLiveSchedule.Event.effective_end(event), buffered_start) == :gt
          end)

        if booked_count >= config.seats, do: :booked, else: :available
    end
  rescue
    e ->
      Logger.warning(
        "[PhoenixLiveSchedule] Error computing slot status for #{inspect(date)} #{inspect(start_time)}: #{Exception.message(e)}"
      )

      :unavailable
  end

  defp datetime_from_date_time(date, time) do
    {:ok, ndt} = NaiveDateTime.new(date, time)
    DateTime.from_naive!(ndt, "Etc/UTC")
  end

  defp compare_dt(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b)
  defp compare_dt(%NaiveDateTime{} = a, %DateTime{} = b), do: compare_dt(to_utc(a), b)
  defp compare_dt(%DateTime{} = a, %NaiveDateTime{} = b), do: compare_dt(a, to_utc(b))

  defp compare_dt(%NaiveDateTime{} = a, %NaiveDateTime{} = b),
    do: NaiveDateTime.compare(a, b)

  defp compare_dt(%Date{} = a, b), do: compare_dt(to_utc_start(a), b)
  defp compare_dt(a, %Date{} = b), do: compare_dt(a, to_utc_start(b))

  defp to_utc(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC")

  defp to_utc_start(%Date{} = d) do
    {:ok, ndt} = NaiveDateTime.new(d, ~T[00:00:00])
    DateTime.from_naive!(ndt, "Etc/UTC")
  end

  defp time_to_seconds(%Time{hour: h, minute: m, second: s}), do: h * 3600 + m * 60 + s

  defp seconds_to_time(seconds) when seconds >= 0 do
    h = div(seconds, 3600)
    m = div(rem(seconds, 3600), 60)
    s = rem(seconds, 60)
    Time.new!(min(h, 23), m, s)
  end
end
