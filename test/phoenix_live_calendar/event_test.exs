defmodule PhoenixLiveCalendar.EventTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveCalendar.Event

  describe "all_day?/1" do
    test "returns true when all_day flag is set" do
      event = %Event{id: "1", start: ~U[2026-04-01 10:00:00Z], all_day: true}
      assert Event.all_day?(event)
    end

    test "returns true when start is a Date" do
      event = %Event{id: "1", start: ~D[2026-04-01]}
      assert Event.all_day?(event)
    end

    test "returns false for timed events" do
      event = %Event{id: "1", start: ~U[2026-04-01 10:00:00Z]}
      refute Event.all_day?(event)
    end
  end

  describe "effective_end/1" do
    test "returns explicit end when set" do
      event = %Event{id: "1", start: ~U[2026-04-01 10:00:00Z], end: ~U[2026-04-01 11:00:00Z]}
      assert Event.effective_end(event) == ~U[2026-04-01 11:00:00Z]
    end

    test "defaults all-day to start + 1 day" do
      event = %Event{id: "1", start: ~D[2026-04-01]}
      assert Event.effective_end(event) == ~D[2026-04-02]
    end

    test "defaults timed to start + 30 minutes" do
      event = %Event{id: "1", start: ~U[2026-04-01 10:00:00Z]}
      assert Event.effective_end(event) == ~U[2026-04-01 10:30:00Z]
    end

    test "defaults NaiveDateTime to start + 30 minutes" do
      event = %Event{id: "1", start: ~N[2026-04-01 10:00:00]}
      assert Event.effective_end(event) == ~N[2026-04-01 10:30:00]
    end
  end

  describe "duration_seconds/1" do
    test "calculates duration for timed events" do
      event = %Event{
        id: "1",
        start: ~U[2026-04-01 10:00:00Z],
        end: ~U[2026-04-01 11:30:00Z]
      }

      assert Event.duration_seconds(event) == 5400
    end

    test "calculates duration for all-day events" do
      event = %Event{id: "1", start: ~D[2026-04-01], end: ~D[2026-04-03]}
      assert Event.duration_seconds(event) == 2 * 86_400
    end
  end

  describe "multi_day?/1" do
    test "returns true for multi-day events" do
      event = %Event{id: "1", start: ~D[2026-04-01], end: ~D[2026-04-03]}
      assert Event.multi_day?(event)
    end

    test "returns false for single-day all-day events" do
      event = %Event{id: "1", start: ~D[2026-04-01]}
      refute Event.multi_day?(event)
    end

    test "returns false for timed events within one day" do
      event = %Event{
        id: "1",
        start: ~U[2026-04-01 10:00:00Z],
        end: ~U[2026-04-01 15:00:00Z]
      }

      refute Event.multi_day?(event)
    end
  end

  describe "on_date?/1" do
    test "all-day event is on its date" do
      event = %Event{id: "1", start: ~D[2026-04-01]}
      assert Event.on_date?(event, ~D[2026-04-01])
    end

    test "all-day event is not on the exclusive end date" do
      event = %Event{id: "1", start: ~D[2026-04-01], end: ~D[2026-04-02]}
      refute Event.on_date?(event, ~D[2026-04-02])
    end

    test "multi-day event spans multiple dates" do
      event = %Event{id: "1", start: ~D[2026-04-01], end: ~D[2026-04-04]}
      assert Event.on_date?(event, ~D[2026-04-01])
      assert Event.on_date?(event, ~D[2026-04-02])
      assert Event.on_date?(event, ~D[2026-04-03])
      refute Event.on_date?(event, ~D[2026-04-04])
    end

    test "timed event is on its date" do
      event = %Event{id: "1", start: ~U[2026-04-01 23:00:00Z], end: ~U[2026-04-02 01:00:00Z]}
      assert Event.on_date?(event, ~D[2026-04-01])
    end
  end

  describe "visible_at?/2" do
    test "event with default visibility (20) is visible at threshold 10" do
      event = %Event{id: "1", start: ~D[2026-04-01]}
      assert Event.visible_at?(event, 10)
    end

    test "event with default visibility (20) is visible at threshold 20" do
      event = %Event{id: "1", start: ~D[2026-04-01]}
      assert Event.visible_at?(event, 20)
    end

    test "event with default visibility (20) is not visible at threshold 30" do
      event = %Event{id: "1", start: ~D[2026-04-01]}
      refute Event.visible_at?(event, 30)
    end

    test "high visibility event (30) shows in month view threshold" do
      event = %Event{id: "1", start: ~D[2026-04-01], visibility: 30}
      assert Event.visible_at?(event, 30)
    end

    test "highest visibility event (40) shows at year threshold" do
      event = %Event{id: "1", start: ~D[2026-04-01], visibility: 40}
      assert Event.visible_at?(event, 40)
    end

    test "granular visibility (25) shows in week (20) but not month (30)" do
      event = %Event{id: "1", start: ~D[2026-04-01], visibility: 25}
      assert Event.visible_at?(event, 20)
      refute Event.visible_at?(event, 30)
    end

    test "low visibility event (10) only shows in day view" do
      event = %Event{id: "1", start: ~D[2026-04-01], visibility: 10}
      assert Event.visible_at?(event, 10)
      refute Event.visible_at?(event, 20)
    end
  end

  describe "overlaps_range?/3" do
    test "detects overlapping events" do
      event = %Event{
        id: "1",
        start: ~U[2026-04-01 10:00:00Z],
        end: ~U[2026-04-01 11:00:00Z]
      }

      assert Event.overlaps_range?(event, ~U[2026-04-01 10:30:00Z], ~U[2026-04-01 12:00:00Z])
    end

    test "detects non-overlapping events" do
      event = %Event{
        id: "1",
        start: ~U[2026-04-01 10:00:00Z],
        end: ~U[2026-04-01 11:00:00Z]
      }

      refute Event.overlaps_range?(event, ~U[2026-04-01 11:00:00Z], ~U[2026-04-01 12:00:00Z])
    end
  end
end
