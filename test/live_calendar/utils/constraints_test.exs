defmodule LiveCalendar.Utils.ConstraintsTest do
  use ExUnit.Case, async: true

  alias LiveCalendar.{Availability, BookingConfig, Event}
  alias LiveCalendar.Utils.Constraints

  @now ~U[2026-04-01 12:00:00Z]

  describe "validate_booking/5" do
    test "accepts valid booking" do
      config = %BookingConfig{duration: 30}

      assert :ok ==
               Constraints.validate_booking(
                 ~U[2026-04-02 10:00:00Z],
                 ~U[2026-04-02 10:30:00Z],
                 config,
                 [],
                 now: @now
               )
    end

    test "rejects booking in the past" do
      config = %BookingConfig{duration: 30}

      assert {:error, :in_past, _} =
               Constraints.validate_booking(
                 ~U[2026-03-31 10:00:00Z],
                 ~U[2026-03-31 10:30:00Z],
                 config,
                 [],
                 now: @now
               )
    end

    test "rejects booking with end before start" do
      config = %BookingConfig{duration: 30}

      assert {:error, :invalid_range, _} =
               Constraints.validate_booking(
                 ~U[2026-04-02 11:00:00Z],
                 ~U[2026-04-02 10:00:00Z],
                 config,
                 [],
                 now: @now
               )
    end

    test "rejects booking shorter than min_duration" do
      config = %BookingConfig{duration: 60, min_duration: 30}

      assert {:error, :too_short, _} =
               Constraints.validate_booking(
                 ~U[2026-04-02 10:00:00Z],
                 ~U[2026-04-02 10:15:00Z],
                 config,
                 [],
                 now: @now
               )
    end

    test "rejects booking longer than max_duration" do
      config = %BookingConfig{duration: 30, max_duration: 60}

      assert {:error, :too_long, _} =
               Constraints.validate_booking(
                 ~U[2026-04-02 10:00:00Z],
                 ~U[2026-04-02 12:00:00Z],
                 config,
                 [],
                 now: @now
               )
    end

    test "rejects booking with insufficient notice" do
      config = %BookingConfig{duration: 30, min_notice: 120}

      assert {:error, :insufficient_notice, _} =
               Constraints.validate_booking(
                 ~U[2026-04-01 13:00:00Z],
                 ~U[2026-04-01 13:30:00Z],
                 config,
                 [],
                 now: @now
               )
    end

    test "rejects booking too far in advance" do
      config = %BookingConfig{duration: 30, max_advance: 7}

      assert {:error, :too_far_ahead, _} =
               Constraints.validate_booking(
                 ~U[2026-04-20 10:00:00Z],
                 ~U[2026-04-20 10:30:00Z],
                 config,
                 [],
                 now: @now
               )
    end

    test "rejects overlapping booking" do
      config = %BookingConfig{duration: 30, max_duration: 60}

      existing = [
        %Event{
          id: "1",
          start: ~U[2026-04-02 10:00:00Z],
          end: ~U[2026-04-02 11:00:00Z],
          overlap: false
        }
      ]

      assert {:error, :overlap, _} =
               Constraints.validate_booking(
                 ~U[2026-04-02 10:30:00Z],
                 ~U[2026-04-02 11:30:00Z],
                 config,
                 existing,
                 now: @now
               )
    end

    test "rejects when at capacity" do
      config = %BookingConfig{duration: 30, seats: 2}

      existing = [
        %Event{id: "1", start: ~U[2026-04-02 10:00:00Z], end: ~U[2026-04-02 10:30:00Z]},
        %Event{id: "2", start: ~U[2026-04-02 10:00:00Z], end: ~U[2026-04-02 10:30:00Z]}
      ]

      assert {:error, :at_capacity, _} =
               Constraints.validate_booking(
                 ~U[2026-04-02 10:00:00Z],
                 ~U[2026-04-02 10:30:00Z],
                 config,
                 existing,
                 now: @now
               )
    end

    test "allows booking when under capacity" do
      config = %BookingConfig{duration: 30, seats: 3}

      existing = [
        %Event{id: "1", start: ~U[2026-04-02 10:00:00Z], end: ~U[2026-04-02 10:30:00Z]},
        %Event{id: "2", start: ~U[2026-04-02 10:00:00Z], end: ~U[2026-04-02 10:30:00Z]}
      ]

      assert :ok ==
               Constraints.validate_booking(
                 ~U[2026-04-02 10:00:00Z],
                 ~U[2026-04-02 10:30:00Z],
                 config,
                 existing,
                 now: @now
               )
    end

    test "validates against availability windows" do
      config = %BookingConfig{duration: 30}

      availability = [
        %Availability{
          days_of_week: [1, 2, 3, 4, 5],
          start_time: ~T[09:00:00],
          end_time: ~T[17:00:00]
        }
      ]

      # 2026-04-02 is Thursday (day 4) — within availability
      assert :ok ==
               Constraints.validate_booking(
                 ~U[2026-04-02 10:00:00Z],
                 ~U[2026-04-02 10:30:00Z],
                 config,
                 [],
                 now: @now,
                 availabilities: availability
               )

      # Outside hours
      assert {:error, :outside_availability, _} =
               Constraints.validate_booking(
                 ~U[2026-04-02 18:00:00Z],
                 ~U[2026-04-02 18:30:00Z],
                 config,
                 [],
                 now: @now,
                 availabilities: availability
               )
    end
  end

  describe "snap_to_slot/2" do
    test "snaps to 15-minute boundaries" do
      assert Constraints.snap_to_slot(~T[10:17:00], 15) == ~T[10:15:00]
      assert Constraints.snap_to_slot(~T[10:00:00], 15) == ~T[10:00:00]
      assert Constraints.snap_to_slot(~T[10:14:00], 15) == ~T[10:00:00]
      assert Constraints.snap_to_slot(~T[10:29:00], 15) == ~T[10:15:00]
    end

    test "snaps to 30-minute boundaries" do
      assert Constraints.snap_to_slot(~T[10:17:00], 30) == ~T[10:00:00]
      assert Constraints.snap_to_slot(~T[10:45:00], 30) == ~T[10:30:00]
    end

    test "snaps to 60-minute boundaries" do
      assert Constraints.snap_to_slot(~T[10:45:00], 60) == ~T[10:00:00]
      assert Constraints.snap_to_slot(~T[11:59:00], 60) == ~T[11:00:00]
    end
  end

  describe "has_overlap?/4" do
    test "detects overlap with buffer_before" do
      config = %BookingConfig{duration: 30, buffer_before: 15}

      existing = [
        %Event{id: "1", start: ~U[2026-04-02 10:00:00Z], end: ~U[2026-04-02 10:30:00Z]}
      ]

      # Proposed 10:20-10:50 with 15min buffer_before → buffered to 10:05-10:50
      # Existing 10:00-10:30 overlaps with 10:05-10:50
      assert Constraints.has_overlap?(
               ~U[2026-04-02 10:20:00Z],
               ~U[2026-04-02 10:50:00Z],
               config,
               existing
             )
    end

    test "no overlap when outside buffer" do
      config = %BookingConfig{duration: 30, buffer_before: 0, buffer_after: 0}

      existing = [
        %Event{id: "1", start: ~U[2026-04-02 10:00:00Z], end: ~U[2026-04-02 10:30:00Z]}
      ]

      # 10:30 exactly is not overlapping (exclusive end)
      refute Constraints.has_overlap?(
               ~U[2026-04-02 10:30:00Z],
               ~U[2026-04-02 11:00:00Z],
               config,
               existing
             )
    end
  end
end
