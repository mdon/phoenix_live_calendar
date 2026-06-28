defmodule LiveCalendar.Utils.TelemetryTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias LiveCalendar.Event
  alias LiveCalendar.Utils.Telemetry

  setup do
    # Save and restore all config after each test
    prev_warnings = Application.get_env(:live_calendar, :perf_warnings)
    prev_thresholds = Application.get_env(:live_calendar, :perf_thresholds)
    prev_always = Application.get_env(:live_calendar, :perf_always_measure)

    on_exit(fn ->
      restore_config(:perf_warnings, prev_warnings)
      restore_config(:perf_thresholds, prev_thresholds)
      restore_config(:perf_always_measure, prev_always)
    end)

    :ok
  end

  defp restore_config(key, nil), do: Application.delete_env(:live_calendar, key)
  defp restore_config(key, val), do: Application.put_env(:live_calendar, key, val)

  describe "measure/3" do
    test "returns the result of the function" do
      assert Telemetry.measure(:test_op, %{}, fn -> 42 end) == 42
    end

    test "emits telemetry span events" do
      test_pid = self()
      handler_id = "test-measure-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:live_calendar, :measure, :stop],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_stop, measurements, metadata})
        end,
        nil
      )

      Telemetry.measure(:test_op, %{extra: "data"}, fn ->
        :timer.sleep(1)
        :ok
      end)

      assert_receive {:telemetry_stop, measurements, metadata}
      assert measurements.duration > 0
      assert metadata.label == :test_op
      assert metadata.extra == "data"

      :telemetry.detach(handler_id)
    end
  end

  describe "measure_and_warn/3" do
    test "returns the result of the function" do
      assert Telemetry.measure_and_warn(:test_op, %{}, fn -> :hello end) == :hello
    end

    test "emits telemetry stop event with duration" do
      test_pid = self()
      handler_id = "test-warn-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:live_calendar, :measure, :stop],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_stop, measurements, metadata})
        end,
        nil
      )

      Telemetry.measure_and_warn(:test_op, %{foo: "bar"}, fn -> :done end)

      assert_receive {:telemetry_stop, measurements, metadata}
      assert measurements.duration >= 0
      assert metadata.label == :test_op
      assert metadata.foo == "bar"
      assert is_float(metadata.duration_ms)

      :telemetry.detach(handler_id)
    end

    test "logs warning when threshold is exceeded" do
      Application.put_env(:live_calendar, :perf_thresholds, %{slow_test: 0})
      Application.put_env(:live_calendar, :perf_warnings, true)

      log =
        capture_log(fn ->
          Telemetry.measure_and_warn(:slow_test, %{items: 5}, fn ->
            :timer.sleep(2)
            :ok
          end)
        end)

      assert log =~ "[LiveCalendar] slow_test took"
      assert log =~ "threshold: 0ms"
      assert log =~ "items: 5"
    end

    test "does not log when under threshold" do
      Application.put_env(:live_calendar, :perf_thresholds, %{fast_test: 5000})

      log =
        capture_log(fn ->
          Telemetry.measure_and_warn(:fast_test, %{}, fn -> :ok end)
        end)

      assert log == ""
    end

    test "respects perf_warnings: false" do
      Application.put_env(:live_calendar, :perf_warnings, false)
      Application.put_env(:live_calendar, :perf_thresholds, %{silent_test: 0})

      log =
        capture_log(fn ->
          Telemetry.measure_and_warn(:silent_test, %{}, fn ->
            :timer.sleep(2)
            :ok
          end)
        end)

      assert log == ""
    end
  end

  describe "profile_ingress/2" do
    test "returns count and estimated bytes for empty list" do
      {count, bytes} = Telemetry.profile_ingress([], :month)
      assert count == 0
      assert bytes == 0
    end

    test "returns count and estimated bytes for small list" do
      events = [
        %Event{id: "1", start: ~D[2026-04-01], title: "Test"},
        %Event{id: "2", start: ~D[2026-04-02], title: "Test 2"}
      ]

      {count, bytes} = Telemetry.profile_ingress(events, :month)
      assert count == 2
      assert bytes > 0
    end

    test "emits telemetry ingress event" do
      test_pid = self()
      handler_id = "test-ingress-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:live_calendar, :ingress],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {:telemetry_ingress, measurements, metadata})
        end,
        nil
      )

      events = [%Event{id: "1", start: ~D[2026-04-01]}]
      Telemetry.profile_ingress(events, :week)

      assert_receive {:telemetry_ingress, measurements, metadata}
      assert measurements.event_count == 1
      assert measurements.estimated_bytes > 0
      assert metadata.view == :week

      :telemetry.detach(handler_id)
    end

    test "warns for large event count" do
      Application.put_env(:live_calendar, :perf_warnings, true)

      events =
        Enum.map(1..501, fn i ->
          %Event{id: "evt-#{i}", start: ~D[2026-04-01], title: "Event #{i}"}
        end)

      log =
        capture_log(fn ->
          {count, _bytes} = Telemetry.profile_ingress(events, :month)
          assert count == 501
        end)

      assert log =~ "[LiveCalendar]"
      assert log =~ "501 events"
      assert log =~ "on_date_range_change"
    end

    test "uses sample-based estimation for large lists" do
      events =
        Enum.map(1..50, fn i ->
          %Event{
            id: "evt-#{i}",
            start: ~D[2026-04-01],
            title: "Event #{i}",
            extra: %{data: String.duplicate("x", 100)}
          }
        end)

      {count, bytes} = Telemetry.profile_ingress(events, :month)
      assert count == 50
      assert bytes > 0
    end
  end

  describe "should_measure?/1" do
    test "returns false for small datasets" do
      refute Telemetry.should_measure?(50)
      refute Telemetry.should_measure?(100)
    end

    test "returns true for datasets over 100" do
      assert Telemetry.should_measure?(101)
      assert Telemetry.should_measure?(500)
    end

    test "respects perf_always_measure config" do
      Application.put_env(:live_calendar, :perf_always_measure, true)

      assert Telemetry.should_measure?(1)
      assert Telemetry.should_measure?(0)
    end
  end

  describe "threshold/1" do
    test "returns default thresholds" do
      assert Telemetry.threshold(:group_events) == 10
      assert Telemetry.threshold(:slot_layout) == 5
      assert Telemetry.threshold(:filter) == 5
      assert Telemetry.threshold(:overlap_layout) == 5
    end

    test "returns 10 for unknown labels" do
      assert Telemetry.threshold(:unknown_thing) == 10
    end

    test "respects custom threshold config" do
      Application.put_env(:live_calendar, :perf_thresholds, %{group_events: 50})

      assert Telemetry.threshold(:group_events) == 50
      # Others unchanged
      assert Telemetry.threshold(:slot_layout) == 5
    end
  end

  describe "warnings_enabled?/0" do
    test "returns true by default" do
      Application.delete_env(:live_calendar, :perf_warnings)
      assert Telemetry.warnings_enabled?()
    end

    test "returns false when configured" do
      Application.put_env(:live_calendar, :perf_warnings, false)
      refute Telemetry.warnings_enabled?()
    end
  end
end
