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

  describe "spans_multiple_dates?/1" do
    test "same-day timed event: false" do
      e = %Event{id: "1", start: ~U[2026-04-06 09:00:00Z], end: ~U[2026-04-06 15:00:00Z]}
      refute Event.spans_multiple_dates?(e)
    end

    test "overnight timed event (10pm→2am): true — it touches two dates" do
      e = %Event{id: "1", start: ~U[2026-04-06 22:00:00Z], end: ~U[2026-04-07 02:00:00Z]}
      assert Event.spans_multiple_dates?(e)
    end

    test "timed event ending exactly at midnight: false (only the start day)" do
      e = %Event{id: "1", start: ~U[2026-04-06 09:00:00Z], end: ~U[2026-04-07 00:00:00Z]}
      refute Event.spans_multiple_dates?(e)
    end

    test "single-day all-day event (exclusive end): false" do
      e = %Event{id: "1", start: ~D[2026-04-06], end: ~D[2026-04-07], all_day: true}
      refute Event.spans_multiple_dates?(e)
    end

    test "multi-day all-day event: true" do
      e = %Event{id: "1", start: ~D[2026-04-06], end: ~D[2026-04-09], all_day: true}
      assert Event.spans_multiple_dates?(e)
    end
  end

  describe "last_date/1" do
    test "all-day event: end is exclusive, so last day is end - 1" do
      event = %Event{id: "1", start: ~D[2026-04-10], end: ~D[2026-04-17], all_day: true}
      assert Event.last_date(event) == ~D[2026-04-16]
    end

    test "timed event ending after midnight occupies its end DATE" do
      # the 17th-stub bug: this event is on the 17th, so the last day is the
      # 17th — must match on_date? (which renders a bar segment there)
      event = %Event{
        id: "1",
        start: ~U[2026-04-10 09:00:00Z],
        end: ~U[2026-04-17 10:00:00Z],
        all_day: false
      }

      assert Event.last_date(event) == ~D[2026-04-17]
      assert Event.on_date?(event, ~D[2026-04-17])
      refute Event.on_date?(event, ~D[2026-04-18])
    end

    test "timed event ending exactly at midnight does NOT occupy that day" do
      event = %Event{
        id: "1",
        start: ~U[2026-04-10 09:00:00Z],
        end: ~U[2026-04-17 00:00:00Z],
        all_day: false
      }

      assert Event.last_date(event) == ~D[2026-04-16]
      refute Event.on_date?(event, ~D[2026-04-17])
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

  describe "first_date/1 and in_range?/3" do
    test "first_date is the start's calendar date" do
      assert Event.first_date(%Event{id: 1, start: ~D[2026-04-05]}) == ~D[2026-04-05]
      assert Event.first_date(%Event{id: 1, start: ~U[2026-04-05 22:00:00Z]}) == ~D[2026-04-05]
    end

    test "in_range? is inclusive-start, exclusive-end" do
      event = %Event{id: 1, start: ~D[2026-04-05], end: ~D[2026-04-06], all_day: true}

      assert Event.in_range?(event, ~D[2026-04-05], ~D[2026-04-06])
      assert Event.in_range?(event, ~D[2026-04-01], ~D[2026-04-06])
      refute Event.in_range?(event, ~D[2026-04-06], ~D[2026-04-10])
      refute Event.in_range?(event, ~D[2026-04-01], ~D[2026-04-05])
    end

    test "a multi-day event straddling a range boundary is in range" do
      event = %Event{id: 1, start: ~D[2026-03-28], end: ~D[2026-04-03], all_day: true}

      assert Event.in_range?(event, ~D[2026-04-01], ~D[2026-05-01])
      assert Event.in_range?(event, ~D[2026-03-01], ~D[2026-03-29])
    end

    test "a midnight-crossing timed event counts on its spill-over day" do
      event = %Event{id: 1, start: ~U[2026-03-31 22:00:00Z], end: ~U[2026-04-01 01:00:00Z]}

      assert Event.in_range?(event, ~D[2026-04-01], ~D[2026-05-01])
    end

    test "an event ending exactly at midnight does not spill over" do
      event = %Event{id: 1, start: ~U[2026-03-31 22:00:00Z], end: ~U[2026-04-01 00:00:00Z]}

      refute Event.in_range?(event, ~D[2026-04-01], ~D[2026-05-01])
    end
  end

  describe "all_day with a DateTime start" do
    test "effective_end defaults to the next day, not +30 minutes" do
      event = %Event{id: 1, start: ~U[2026-04-01 09:00:00Z], all_day: true}

      # +30min put last_date on the PREVIOUS day and every occupancy
      # consumer dropped the event
      assert Event.effective_end(event) == ~D[2026-04-02]
      assert Event.last_date(event) == ~D[2026-04-01]
      assert Event.on_date?(event, ~D[2026-04-01])
    end
  end

  describe "on_resource?/2" do
    test "matches the singular id and plural membership" do
      event = %Event{id: 1, start: ~D[2026-04-01], resource_id: "a", resource_ids: ["b", "c"]}

      assert Event.on_resource?(event, "a")
      assert Event.on_resource?(event, "b")
      refute Event.on_resource?(event, "x")
    end
  end

  describe "day_window/4" do
    test "clips to the date and window; exact-midnight ends stay on their day" do
      event = %Event{id: 1, start: ~U[2026-04-01 22:00:00Z], end: ~U[2026-04-02 00:00:00Z]}

      assert Event.day_window(event, ~D[2026-04-01]) == {~T[22:00:00], ~T[23:59:59]}
      assert Event.day_window(event, ~D[2026-04-01], ~T[06:00:00], ~T[22:00:00]) == nil
    end

    test "midnight-crossers split across both days" do
      event = %Event{id: 1, start: ~U[2026-04-01 21:30:00Z], end: ~U[2026-04-02 01:00:00Z]}

      assert Event.day_window(event, ~D[2026-04-01]) == {~T[21:30:00], ~T[23:59:59]}
      assert Event.day_window(event, ~D[2026-04-02]) == {~T[00:00:00], ~T[01:00:00]}
    end

    test "all-day events span the visible window" do
      event = %Event{id: 1, start: ~D[2026-04-01], all_day: true}

      assert Event.day_window(event, ~D[2026-04-01], ~T[08:00:00], ~T[18:00:00]) ==
               {~T[08:00:00], ~T[18:00:00]}
    end
  end
end
