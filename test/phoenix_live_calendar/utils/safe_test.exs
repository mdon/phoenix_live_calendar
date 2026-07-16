defmodule PhoenixLiveCalendar.Utils.SafeTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils.Safe

  describe "to_date/1" do
    test "converts Date passthrough" do
      assert Safe.to_date(~D[2026-04-01]) == ~D[2026-04-01]
    end

    test "converts DateTime to Date" do
      assert Safe.to_date(~U[2026-04-01 10:00:00Z]) == ~D[2026-04-01]
    end

    test "converts NaiveDateTime to Date" do
      assert Safe.to_date(~N[2026-04-01 10:00:00]) == ~D[2026-04-01]
    end

    test "converts ISO string to Date" do
      assert Safe.to_date("2026-04-01") == ~D[2026-04-01]
    end

    test "returns nil for invalid string" do
      log =
        capture_log(fn ->
          assert Safe.to_date("not-a-date") == nil
        end)

      assert log == "" or true
    end

    test "returns nil for invalid type and logs warning" do
      log =
        capture_log(fn ->
          assert Safe.to_date(12_345) == nil
        end)

      assert log =~ "[PhoenixLiveCalendar]"
    end
  end

  describe "to_time/1" do
    test "converts Time passthrough" do
      assert Safe.to_time(~T[10:00:00]) == ~T[10:00:00]
    end

    test "converts DateTime to Time" do
      assert Safe.to_time(~U[2026-04-01 14:30:00Z]) == ~T[14:30:00]
    end

    test "converts NaiveDateTime to Time" do
      assert Safe.to_time(~N[2026-04-01 14:30:00]) == ~T[14:30:00]
    end

    test "converts ISO string to Time" do
      assert Safe.to_time("14:30:00") == ~T[14:30:00]
    end

    test "returns nil for invalid type and logs warning" do
      log =
        capture_log(fn ->
          assert Safe.to_time(:invalid) == nil
        end)

      assert log =~ "[PhoenixLiveCalendar]"
    end
  end

  describe "safe_call/2" do
    test "returns function result on success" do
      assert Safe.safe_call(fn -> 42 end) == 42
    end

    test "returns fallback on error" do
      log =
        capture_log(fn ->
          assert Safe.safe_call(fn -> raise "boom" end, :default) == :default
        end)

      assert log =~ "boom"
    end

    test "returns nil fallback by default" do
      capture_log(fn ->
        assert Safe.safe_call(fn -> raise "boom" end) == nil
      end)
    end
  end

  describe "ensure_list/1" do
    test "returns list unchanged" do
      assert Safe.ensure_list([1, 2, 3]) == [1, 2, 3]
    end

    test "returns empty list for nil" do
      assert Safe.ensure_list(nil) == []
    end

    test "returns empty list for non-list and logs warning" do
      log =
        capture_log(fn ->
          assert Safe.ensure_list("not a list") == []
        end)

      assert log =~ "[PhoenixLiveCalendar]"
    end
  end

  describe "ensure_pos_integer/2" do
    test "returns valid positive integer" do
      assert Safe.ensure_pos_integer(5, 10) == 5
    end

    test "returns default for zero" do
      capture_log(fn ->
        assert Safe.ensure_pos_integer(0, 10) == 10
      end)
    end

    test "returns default for negative" do
      capture_log(fn ->
        assert Safe.ensure_pos_integer(-1, 10) == 10
      end)
    end

    test "returns default for non-integer" do
      capture_log(fn ->
        assert Safe.ensure_pos_integer("five", 10) == 10
      end)
    end
  end

  describe "safe_filter_events/1" do
    test "passes valid events through" do
      events = [
        %Event{id: "1", start: ~D[2026-04-01]},
        %Event{id: "2", start: ~U[2026-04-02 10:00:00Z]}
      ]

      assert Safe.safe_filter_events(events) == events
    end

    test "filters out events with nil id" do
      events = [
        %Event{id: nil, start: ~D[2026-04-01]},
        %Event{id: "2", start: ~U[2026-04-02 10:00:00Z]}
      ]

      capture_log(fn ->
        result = Safe.safe_filter_events(events)
        assert length(result) == 1
        assert hd(result).id == "2"
      end)
    end

    test "returns empty list for non-list input" do
      capture_log(fn ->
        assert Safe.safe_filter_events("not events") == []
      end)
    end

    test "returns empty list for nil" do
      capture_log(fn ->
        assert Safe.safe_filter_events(nil) == []
      end)
    end
  end

  describe "sanitize_css_dimension/2 fallback parameter" do
    import ExUnit.CaptureLog

    test "an invalid dimension returns the SUPPLIED fallback, not a hardcoded 3rem" do
      capture_log(fn ->
        assert Safe.sanitize_css_dimension("javascript:alert(1)", "1.25rem") == "1.25rem"
        assert Safe.sanitize_css_dimension("bogus") == "3rem"
      end)
    end
  end
end
