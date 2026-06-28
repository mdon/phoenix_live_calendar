defmodule PhoenixLiveSchedule.Utils.TimeSlotsTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveSchedule.Utils.TimeSlots

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
end
