defmodule PhoenixLiveCalendar.Utils.TimeSlotsTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveCalendar.{Availability, BookingConfig, Event}
  alias PhoenixLiveCalendar.Utils.TimeSlots

  describe "time_grid_slots/1" do
    test "generates slots for a full day" do
      slots = TimeSlots.time_grid_slots(slot_duration: 60)
      assert length(slots) == 24
      assert hd(slots) == ~T[00:00:00]
    end

    test "generates 30-minute slots" do
      slots = TimeSlots.time_grid_slots(slot_duration: 30)
      assert length(slots) == 48
    end

    test "respects min_time and max_time" do
      slots =
        TimeSlots.time_grid_slots(min_time: ~T[09:00:00], max_time: ~T[17:00:00], slot_duration: 60)

      assert length(slots) == 8
      assert hd(slots) == ~T[09:00:00]
      assert List.last(slots) == ~T[16:00:00]
    end

    test "generates 15-minute slots" do
      slots =
        TimeSlots.time_grid_slots(min_time: ~T[09:00:00], max_time: ~T[10:00:00], slot_duration: 15)

      assert length(slots) == 4
      assert slots == [~T[09:00:00], ~T[09:15:00], ~T[09:30:00], ~T[09:45:00]]
    end
  end

  describe "time_to_percentage/2" do
    test "midnight is 0%" do
      assert TimeSlots.time_to_percentage(~T[00:00:00]) == 0.0
    end

    test "noon is ~50%" do
      pct = TimeSlots.time_to_percentage(~T[12:00:00])
      assert_in_delta pct, 50.0, 0.1
    end

    test "respects custom min/max range" do
      pct =
        TimeSlots.time_to_percentage(~T[12:00:00], min_time: ~T[08:00:00], max_time: ~T[20:00:00])

      assert_in_delta pct, 33.33, 0.1
    end

    test "clamps to 0-100" do
      assert TimeSlots.time_to_percentage(~T[07:00:00],
               min_time: ~T[08:00:00],
               max_time: ~T[20:00:00]
             ) == 0.0
    end
  end

  describe "duration_to_percentage/3" do
    test "calculates height for 1 hour in full day" do
      pct = TimeSlots.duration_to_percentage(~T[10:00:00], ~T[11:00:00])
      assert_in_delta pct, 4.17, 0.1
    end

    test "calculates height in custom range" do
      pct =
        TimeSlots.duration_to_percentage(
          ~T[09:00:00],
          ~T[10:00:00],
          min_time: ~T[08:00:00],
          max_time: ~T[20:00:00]
        )

      assert_in_delta pct, 8.33, 0.1
    end
  end

  describe "to_time/1" do
    test "converts DateTime to Time" do
      assert TimeSlots.to_time(~U[2026-04-01 14:30:00Z]) == ~T[14:30:00]
    end

    test "converts NaiveDateTime to Time" do
      assert TimeSlots.to_time(~N[2026-04-01 14:30:00]) == ~T[14:30:00]
    end

    test "passes through Time unchanged" do
      assert TimeSlots.to_time(~T[14:30:00]) == ~T[14:30:00]
    end
  end

  describe "bookable_slots/4" do
    # 2026-04-01 is a Wednesday (ISO day 3); 2026-04-04 is a Saturday.
    test "generates back-to-back available slots within the window, none exceeding it" do
      slots =
        TimeSlots.bookable_slots(~D[2026-04-01], %BookingConfig{duration: 30}, weekday_avail(), [])

      # 09:00–17:00 in 30-min slots = 16
      assert length(slots) == 16
      assert hd(slots) == {~T[09:00:00], ~T[09:30:00], :available}
      assert List.last(slots) == {~T[16:30:00], ~T[17:00:00], :available}
      assert Enum.all?(slots, fn {_s, _e, status} -> status == :available end)
    end

    test "returns [] on a day with no applicable availability window" do
      assert TimeSlots.bookable_slots(~D[2026-04-04], %BookingConfig{}, weekday_avail(), []) == []
    end

    test "returns [] when the matching window is marked unavailable" do
      closed = [
        %Availability{
          days_of_week: [3],
          start_time: ~T[09:00:00],
          end_time: ~T[17:00:00],
          available: false
        }
      ]

      assert TimeSlots.bookable_slots(~D[2026-04-01], %BookingConfig{}, closed, []) == []
    end

    test "marks a slot :booked when an existing event fills it (seats: 1)" do
      event = %Event{
        id: "e",
        start: slot_dt(~D[2026-04-01], ~T[09:00:00]),
        end: slot_dt(~D[2026-04-01], ~T[09:30:00]),
        all_day: false
      }

      slots =
        TimeSlots.bookable_slots(~D[2026-04-01], %BookingConfig{duration: 30}, weekday_avail(), [
          event
        ])

      assert {~T[09:00:00], ~T[09:30:00], :booked} =
               Enum.find(slots, &(elem(&1, 0) == ~T[09:00:00]))

      assert {~T[09:30:00], ~T[10:00:00], :available} =
               Enum.find(slots, &(elem(&1, 0) == ~T[09:30:00]))
    end

    test "shared seats keep a slot available until all seats are taken" do
      one = %Event{
        id: "1",
        start: slot_dt(~D[2026-04-01], ~T[09:00:00]),
        end: slot_dt(~D[2026-04-01], ~T[09:30:00]),
        all_day: false
      }

      slots =
        TimeSlots.bookable_slots(
          ~D[2026-04-01],
          %BookingConfig{duration: 30, seats: 2},
          weekday_avail(),
          [one]
        )

      assert {~T[09:00:00], _, :available} = Enum.find(slots, &(elem(&1, 0) == ~T[09:00:00]))
    end

    test "min_notice makes too-soon (past) slots :unavailable" do
      # A past date is always within now + min_notice, so every slot is too soon.
      slots =
        TimeSlots.bookable_slots(
          ~D[2020-01-01],
          %BookingConfig{duration: 30, min_notice: 120},
          all_days_avail(),
          []
        )

      assert slots != []
      assert Enum.all?(slots, fn {_s, _e, status} -> status == :unavailable end)
    end

    test "max_advance makes too-far-out slots :unavailable" do
      far = Date.add(Date.utc_today(), 60)

      slots =
        TimeSlots.bookable_slots(
          far,
          %BookingConfig{duration: 30, max_advance: 7},
          all_days_avail(),
          []
        )

      assert slots != []
      assert Enum.all?(slots, fn {_s, _e, status} -> status == :unavailable end)
    end

    test "all-day events do not book time slots" do
      allday = %Event{id: "ad", start: ~D[2026-04-01], end: ~D[2026-04-02], all_day: true}

      slots =
        TimeSlots.bookable_slots(~D[2026-04-01], %BookingConfig{duration: 30}, weekday_avail(), [
          allday
        ])

      assert Enum.all?(slots, fn {_s, _e, status} -> status == :available end)
    end
  end

  defp weekday_avail do
    [%Availability{days_of_week: [1, 2, 3, 4, 5], start_time: ~T[09:00:00], end_time: ~T[17:00:00]}]
  end

  defp all_days_avail do
    [
      %Availability{
        days_of_week: [1, 2, 3, 4, 5, 6, 7],
        start_time: ~T[09:00:00],
        end_time: ~T[17:00:00]
      }
    ]
  end

  defp slot_dt(date, time), do: DateTime.from_naive!(NaiveDateTime.new!(date, time), "Etc/UTC")

  describe "non-positive slot_duration" do
    test "falls back to 30-minute slots instead of hanging" do
      # 0 || 30 == 0 in Elixir, so a caller's 0 used to reach the slot
      # generator and spin Stream.iterate forever (render hang).
      slots =
        TimeSlots.time_grid_slots(
          min_time: ~T[09:00:00],
          max_time: ~T[11:00:00],
          slot_duration: 0
        )

      assert slots == [~T[09:00:00], ~T[09:30:00], ~T[10:00:00], ~T[10:30:00]]

      assert TimeSlots.time_grid_slots(
               min_time: ~T[09:00:00],
               max_time: ~T[10:00:00],
               slot_duration: -15
             ) == [~T[09:00:00], ~T[09:30:00]]
    end
  end
end
