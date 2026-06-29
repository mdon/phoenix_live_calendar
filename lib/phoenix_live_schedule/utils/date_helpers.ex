defmodule PhoenixLiveSchedule.Utils.DateHelpers do
  @moduledoc """
  Date math utilities for calendar grid generation.

  Handles month grid computation, week boundaries, day ranges, and date
  arithmetic needed by the calendar view components.

  All functions are defensively coded — invalid inputs return safe defaults
  rather than crashing.

  ## Week start day

  All functions accept a `week_start` parameter (1-7, ISO day numbering):
  - 1 = Monday (default, ISO standard)
  - 6 = Saturday
  - 7 = Sunday

  This matches PhoenixKit's `week_start_day` setting.
  """

  require Logger

  alias PhoenixLiveSchedule.Utils.Telemetry

  @doc """
  Returns a flat list of dates for a month grid view.

  The grid always contains complete weeks (rows of 7 days). It starts from
  the first day of the week containing the month's first day, and extends
  to fill either 5 or 6 complete weeks.

  ## Options

  - `week_start` — First day of week (1-7, default: 1 = Monday)
  - `fixed_weeks` — Always show 6 weeks (default: true). When false,
    shows 5 weeks if the month fits.

  ## Examples

      iex> dates = DateHelpers.month_grid(~D[2026-04-01])
      iex> length(dates)
      42
      iex> hd(dates)
      ~D[2026-03-30]
  """
  @spec month_grid(Date.t(), keyword()) :: [Date.t()]
  def month_grid(%Date{} = date, opts \\ []) do
    week_start = Keyword.get(opts, :week_start, 1)
    fixed_weeks = Keyword.get(opts, :fixed_weeks, true)

    first_of_month = Date.beginning_of_month(date)
    last_of_month = Date.end_of_month(date)

    grid_start = week_start_date(first_of_month, week_start)
    grid_end = week_end_date(last_of_month, week_start)

    # Calculate number of days
    days = Date.diff(grid_end, grid_start) + 1
    weeks = div(days, 7)

    # Pad to 6 weeks if fixed
    total_days =
      if fixed_weeks and weeks < 6 do
        42
      else
        weeks * 7
      end

    Enum.map(0..(total_days - 1), fn offset ->
      Date.add(grid_start, offset)
    end)
  end

  @doc """
  Returns a list of dates for a week containing the given date.

  ## Examples

      iex> DateHelpers.week_dates(~D[2026-04-01])
      [~D[2026-03-30], ~D[2026-03-31], ~D[2026-04-01], ~D[2026-04-02],
       ~D[2026-04-03], ~D[2026-04-04], ~D[2026-04-05]]
  """
  @spec week_dates(Date.t(), keyword()) :: [Date.t()]
  def week_dates(%Date{} = date, opts \\ []) do
    week_start = Keyword.get(opts, :week_start, 1)
    start = week_start_date(date, week_start)
    Enum.map(0..6, &Date.add(start, &1))
  end

  @doc """
  Returns a list of dates for an N-day view starting from the given date.

  ## Examples

      iex> DateHelpers.n_day_dates(~D[2026-04-01], 4)
      [~D[2026-04-01], ~D[2026-04-02], ~D[2026-04-03], ~D[2026-04-04]]
  """
  @spec n_day_dates(Date.t(), pos_integer()) :: [Date.t()]
  def n_day_dates(%Date{} = start_date, n) when n > 0 do
    Enum.map(0..(n - 1), &Date.add(start_date, &1))
  end

  @doc """
  Returns a list of 12 `{year, month}` tuples for the year view.

  ## Examples

      iex> DateHelpers.year_months(2026)
      [{2026, 1}, {2026, 2}, ..., {2026, 12}]
  """
  @spec year_months(integer()) :: [{integer(), integer()}]
  def year_months(year) when is_integer(year) do
    Enum.map(1..12, &{year, &1})
  end

  @doc """
  Returns the first day of the week containing the given date.
  """
  @spec week_start_date(Date.t(), integer()) :: Date.t()
  def week_start_date(%Date{} = date, week_start \\ 1) when week_start in 1..7 do
    current_day = Date.day_of_week(date)
    diff = rem(current_day - week_start + 7, 7)
    Date.add(date, -diff)
  end

  @doc """
  Returns the last day of the week containing the given date.
  """
  @spec week_end_date(Date.t(), integer()) :: Date.t()
  def week_end_date(%Date{} = date, week_start \\ 1) do
    start = week_start_date(date, week_start)
    Date.add(start, 6)
  end

  @doc """
  Returns the visible date range for a given view and anchor date.

  Returns `{start_date, end_date}` (inclusive start, exclusive end).
  """
  @spec visible_range(atom(), Date.t(), keyword()) :: {Date.t(), Date.t()}
  def visible_range(view, date, opts \\ [])

  def visible_range(:month, %Date{} = date, opts) do
    grid = month_grid(date, opts)
    {hd(grid), Date.add(List.last(grid), 1)}
  end

  def visible_range(:week, %Date{} = date, opts) do
    dates = week_dates(date, opts)
    {hd(dates), Date.add(List.last(dates), 1)}
  end

  def visible_range(:day, %Date{} = date, _opts) do
    {date, Date.add(date, 1)}
  end

  def visible_range(:year, %Date{} = date, _opts) do
    {Date.new!(date.year, 1, 1), Date.new!(date.year + 1, 1, 1)}
  end

  def visible_range({:n_day, n}, %Date{} = date, _opts) do
    {date, Date.add(date, n)}
  end

  def visible_range(:agenda, %Date{} = date, _opts) do
    {date, Date.add(date, 30)}
  end

  def visible_range(:timeline, %Date{} = date, _opts) do
    {date, Date.add(date, 1)}
  end

  def visible_range(:resource, %Date{} = date, _opts) do
    {date, Date.add(date, 1)}
  end

  # Catch-all — default to single day
  def visible_range(_view, %Date{} = date, _opts) do
    {date, Date.add(date, 1)}
  end

  @doc """
  Shifts the anchor date by one step for the given view.

  ## Examples

      iex> DateHelpers.shift(~D[2026-04-15], :month, :next)
      ~D[2026-05-15]

      iex> DateHelpers.shift(~D[2026-04-15], :week, :prev)
      ~D[2026-04-08]
  """
  @spec shift(Date.t(), atom(), :prev | :next) :: Date.t()
  def shift(date, :month, :next), do: shift_month(date, 1)
  def shift(date, :month, :prev), do: shift_month(date, -1)
  def shift(date, :week, :next), do: Date.add(date, 7)
  def shift(date, :week, :prev), do: Date.add(date, -7)
  def shift(date, :day, :next), do: Date.add(date, 1)
  def shift(date, :day, :prev), do: Date.add(date, -1)
  def shift(date, :year, :next), do: shift_year(date, 1)
  def shift(date, :year, :prev), do: shift_year(date, -1)

  def shift(date, {:n_day, n}, :next), do: Date.add(date, n)
  def shift(date, {:n_day, n}, :prev), do: Date.add(date, -n)

  # Agenda shifts by 30 days
  def shift(date, :agenda, :next), do: Date.add(date, 30)
  def shift(date, :agenda, :prev), do: Date.add(date, -30)

  # Timeline and resource shift by 1 day
  def shift(date, :timeline, :next), do: Date.add(date, 1)
  def shift(date, :timeline, :prev), do: Date.add(date, -1)
  def shift(date, :resource, :next), do: Date.add(date, 1)
  def shift(date, :resource, :prev), do: Date.add(date, -1)

  # Catch-all — shift by 1 day
  def shift(date, _view, :next), do: Date.add(date, 1)
  def shift(date, _view, :prev), do: Date.add(date, -1)

  @doc """
  Returns whether the given date is today.
  """
  @spec today?(Date.t()) :: boolean()
  def today?(%Date{} = date), do: Date.compare(date, Date.utc_today()) == :eq

  @doc """
  Returns whether the given date is in the specified month.
  """
  @spec in_month?(Date.t(), Date.t()) :: boolean()
  def in_month?(%Date{} = date, %Date{} = month_date) do
    date.year == month_date.year and date.month == month_date.month
  end

  @doc """
  Returns whether the given date is a weekend (Saturday or Sunday).
  """
  @spec weekend?(Date.t()) :: boolean()
  def weekend?(%Date{} = date) do
    Date.day_of_week(date) in [6, 7]
  end

  @doc """
  Returns the ISO week number for the given date.
  """
  @spec week_number(Date.t()) :: {integer(), integer()}
  def week_number(%Date{} = date) do
    {year, week} = :calendar.iso_week_number(Date.to_erl(date))
    {year, week}
  end

  @doc """
  Groups a flat list of dates into weeks (lists of 7 dates).
  """
  @spec group_by_weeks([Date.t()]) :: [[Date.t()]]
  def group_by_weeks(dates) do
    Enum.chunk_every(dates, 7)
  end

  @doc """
  Groups events by date for efficient lookup.

  Returns a map of `%{Date.t() => [Event.t()]}`.
  """
  @spec group_events_by_date([PhoenixLiveSchedule.Event.t()], [Date.t()]) :: %{
          Date.t() => [PhoenixLiveSchedule.Event.t()]
        }
  def group_events_by_date(events, dates) do
    event_count = length(events)
    date_count = length(dates)

    do_group = fn ->
      # Initialize all dates with empty lists
      base = Map.new(dates, &{&1, []})

      # Filter out any invalid events that would crash on_date?
      safe_events =
        Enum.filter(events, fn
          %PhoenixLiveSchedule.Event{id: id, start: start}
          when not is_nil(id) and not is_nil(start) ->
            true

          invalid ->
            Logger.warning(
              "[PhoenixLiveSchedule] Skipping invalid event in grouping: #{inspect(invalid)}"
            )

            false
        end)

      Enum.reduce(safe_events, base, fn event, acc ->
        Enum.reduce(dates, acc, &put_event_on_date(event, &1, &2))
      end)
      |> Map.new(fn {date, events} -> {date, Enum.reverse(events)} end)
    end

    if Telemetry.should_measure?(event_count) do
      Telemetry.measure_and_warn(:group_events, %{events: event_count, dates: date_count}, do_group)
    else
      do_group.()
    end
  end

  # -- Private helpers --

  defp put_event_on_date(event, date, acc) do
    if PhoenixLiveSchedule.Event.on_date?(event, date) do
      Map.update!(acc, date, &[event | &1])
    else
      acc
    end
  rescue
    e ->
      Logger.warning(
        "[PhoenixLiveSchedule] Error grouping event #{inspect(event.id)}: #{Exception.message(e)}"
      )

      acc
  end

  defp shift_month(%Date{year: y, month: m, day: d}, offset) do
    total_months = y * 12 + (m - 1) + offset
    new_year = div(total_months, 12)
    new_month = rem(total_months, 12) + 1

    # Clamp day to last day of new month
    max_day = Calendar.ISO.days_in_month(new_year, new_month)
    Date.new!(new_year, new_month, min(d, max_day))
  end

  defp shift_year(%Date{year: y, month: m, day: d}, offset) do
    new_year = y + offset
    max_day = Calendar.ISO.days_in_month(new_year, m)
    Date.new!(new_year, m, min(d, max_day))
  end
end
