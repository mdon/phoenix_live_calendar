defmodule PhoenixLiveCalendar.Utils.DateHelpersTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveCalendar.Utils.DateHelpers

  describe "month_grid/2" do
    test "returns 42 dates by default (6 weeks)" do
      dates = DateHelpers.month_grid(~D[2026-04-01])
      assert length(dates) == 42
    end

    test "starts on the correct week start day (Monday)" do
      dates = DateHelpers.month_grid(~D[2026-04-01], week_start: 1)
      first = hd(dates)
      assert Date.day_of_week(first) == 1
    end

    test "starts on Sunday when week_start is 7" do
      dates = DateHelpers.month_grid(~D[2026-04-01], week_start: 7)
      first = hd(dates)
      assert Date.day_of_week(first) == 7
    end

    test "includes dates from adjacent months" do
      dates = DateHelpers.month_grid(~D[2026-04-01])
      first = hd(dates)
      last = List.last(dates)

      # April 2026 starts on Wednesday, so Monday week start means March 30
      assert first.month == 3 or first.month == 4
      assert last.month == 4 or last.month == 5
    end

    test "all dates are sequential" do
      dates = DateHelpers.month_grid(~D[2026-04-01])

      dates
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] ->
        assert Date.diff(b, a) == 1
      end)
    end
  end

  describe "week_dates/2" do
    test "returns 7 dates" do
      dates = DateHelpers.week_dates(~D[2026-04-01])
      assert length(dates) == 7
    end

    test "starts on Monday by default" do
      dates = DateHelpers.week_dates(~D[2026-04-01])
      assert Date.day_of_week(hd(dates)) == 1
    end

    test "starts on Sunday when configured" do
      dates = DateHelpers.week_dates(~D[2026-04-01], week_start: 7)
      assert Date.day_of_week(hd(dates)) == 7
    end

    test "contains the given date" do
      date = ~D[2026-04-01]
      dates = DateHelpers.week_dates(date)
      assert date in dates
    end
  end

  describe "n_day_dates/2" do
    test "returns correct number of days" do
      dates = DateHelpers.n_day_dates(~D[2026-04-01], 4)
      assert length(dates) == 4
    end

    test "starts from the given date" do
      dates = DateHelpers.n_day_dates(~D[2026-04-01], 3)
      assert hd(dates) == ~D[2026-04-01]
      assert List.last(dates) == ~D[2026-04-03]
    end
  end

  describe "week_start_date/2" do
    test "returns Monday for a Wednesday with Monday start" do
      assert DateHelpers.week_start_date(~D[2026-04-01], 1) == ~D[2026-03-30]
    end

    test "returns the same day if it is the start" do
      # 2026-03-30 is a Monday
      assert DateHelpers.week_start_date(~D[2026-03-30], 1) == ~D[2026-03-30]
    end

    test "returns Sunday for Saturday with Sunday start" do
      # 2026-04-04 is Saturday
      assert DateHelpers.week_start_date(~D[2026-04-04], 7) == ~D[2026-03-29]
    end
  end

  describe "shift/3" do
    test "shifts month forward" do
      assert DateHelpers.shift(~D[2026-04-15], :month, :next) == ~D[2026-05-15]
    end

    test "shifts month backward" do
      assert DateHelpers.shift(~D[2026-04-15], :month, :prev) == ~D[2026-03-15]
    end

    test "clamps day when shifting to shorter month" do
      assert DateHelpers.shift(~D[2026-01-31], :month, :next) == ~D[2026-02-28]
    end

    test "shifts week forward" do
      assert DateHelpers.shift(~D[2026-04-01], :week, :next) == ~D[2026-04-08]
    end

    test "shifts day forward" do
      assert DateHelpers.shift(~D[2026-04-01], :day, :next) == ~D[2026-04-02]
    end

    test "shifts year forward" do
      assert DateHelpers.shift(~D[2026-04-01], :year, :next) == ~D[2027-04-01]
    end

    test "shifts n_day forward" do
      assert DateHelpers.shift(~D[2026-04-01], {:n_day, 4}, :next) == ~D[2026-04-05]
    end
  end

  describe "visible_range/3" do
    test "month range includes padding weeks" do
      {start, end_date} = DateHelpers.visible_range(:month, ~D[2026-04-15])
      assert Date.compare(start, ~D[2026-04-01]) != :gt
      assert Date.compare(end_date, ~D[2026-04-30]) != :lt
    end

    test "week range is exactly 7 days" do
      {start, end_date} = DateHelpers.visible_range(:week, ~D[2026-04-01])
      assert Date.diff(end_date, start) == 7
    end

    test "day range is exactly 1 day" do
      {start, end_date} = DateHelpers.visible_range(:day, ~D[2026-04-01])
      assert Date.diff(end_date, start) == 1
    end

    test "year range is full year" do
      {start, end_date} = DateHelpers.visible_range(:year, ~D[2026-06-15])
      assert start == ~D[2026-01-01]
      assert end_date == ~D[2027-01-01]
    end
  end

  describe "helper functions" do
    test "today?/1 returns true for today" do
      assert DateHelpers.today?(Date.utc_today())
    end

    test "today?/1 returns false for other dates" do
      refute DateHelpers.today?(~D[2020-01-01])
    end

    test "weekend?/1 detects weekends" do
      # 2026-04-04 is Saturday, 2026-04-05 is Sunday
      assert DateHelpers.weekend?(~D[2026-04-04])
      assert DateHelpers.weekend?(~D[2026-04-05])
      refute DateHelpers.weekend?(~D[2026-04-01])
    end

    test "in_month?/2 checks month membership" do
      assert DateHelpers.in_month?(~D[2026-04-15], ~D[2026-04-01])
      refute DateHelpers.in_month?(~D[2026-03-31], ~D[2026-04-01])
    end

    test "group_by_weeks/1 chunks into groups of 7" do
      dates = DateHelpers.month_grid(~D[2026-04-01])
      weeks = DateHelpers.group_by_weeks(dates)
      assert length(weeks) == 6
      Enum.each(weeks, fn week -> assert length(week) == 7 end)
    end

    test "group_by_weeks/2 chunks a weekend-filtered grid into 5-day rows that stay aligned" do
      weekdays =
        ~D[2026-04-01]
        |> DateHelpers.month_grid()
        |> Enum.reject(&DateHelpers.weekend?/1)

      weeks = DateHelpers.group_by_weeks(weekdays, 5)

      Enum.each(weeks, fn week ->
        assert length(week) == 5
        # Every row starts on a Monday — chunking by 7 bled two days of the
        # next week into each row and shifted the whole grid.
        assert Date.day_of_week(hd(week)) == 1
      end)
    end
  end
end
