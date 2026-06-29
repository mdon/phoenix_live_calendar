defmodule PhoenixLiveSchedule.DayMarkerTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveSchedule.DayMarker

  defp single, do: %DayMarker{id: "payday", label: "Payday", start_date: ~D[2026-04-15]}

  defp multi,
    do: %DayMarker{
      id: "xmas",
      label: "Christmas",
      start_date: ~D[2026-12-25],
      end_date: ~D[2026-12-28]
    }

  describe "effective_end_date/1" do
    test "defaults to start + 1 day when end_date is nil" do
      assert DayMarker.effective_end_date(single()) == ~D[2026-04-16]
    end

    test "uses the explicit end_date when present" do
      assert DayMarker.effective_end_date(multi()) == ~D[2026-12-28]
    end
  end

  describe "covers_date?/2" do
    test "single-day marker covers only its start date" do
      assert DayMarker.covers_date?(single(), ~D[2026-04-15])
      refute DayMarker.covers_date?(single(), ~D[2026-04-16])
      refute DayMarker.covers_date?(single(), ~D[2026-04-14])
    end

    test "multi-day marker covers [start, end) — end is exclusive" do
      assert DayMarker.covers_date?(multi(), ~D[2026-12-25])
      assert DayMarker.covers_date?(multi(), ~D[2026-12-27])
      refute DayMarker.covers_date?(multi(), ~D[2026-12-28])
      refute DayMarker.covers_date?(multi(), ~D[2026-12-24])
    end
  end

  describe "span_days/1" do
    test "single-day marker spans 1 day" do
      assert DayMarker.span_days(single()) == 1
    end

    test "multi-day marker spans the exclusive range" do
      assert DayMarker.span_days(multi()) == 3
    end
  end

  describe "markers_for_date/2" do
    test "returns only the markers covering the date" do
      assert DayMarker.markers_for_date([single(), multi()], ~D[2026-04-15]) == [single()]
      assert DayMarker.markers_for_date([single(), multi()], ~D[2026-12-26]) == [multi()]
    end

    test "returns [] when no marker covers the date" do
      assert DayMarker.markers_for_date([single(), multi()], ~D[2026-01-01]) == []
    end
  end

  describe "group_by_date/2" do
    test "keys every requested date, placing covering markers" do
      dates = [~D[2026-12-25], ~D[2026-12-26], ~D[2026-12-27], ~D[2026-12-28]]
      grouped = DayMarker.group_by_date([multi()], dates)

      assert grouped[~D[2026-12-25]] == [multi()]
      assert grouped[~D[2026-12-27]] == [multi()]
      assert grouped[~D[2026-12-28]] == []
      assert Map.keys(grouped) |> Enum.sort() == dates
    end

    test "empty marker list yields every date keyed to []" do
      dates = [~D[2026-04-15], ~D[2026-04-16]]
      assert DayMarker.group_by_date([], dates) == %{~D[2026-04-15] => [], ~D[2026-04-16] => []}
    end

    test "multiple markers on the same date collect together" do
      also = %DayMarker{id: "p2", label: "Other", start_date: ~D[2026-04-15]}
      grouped = DayMarker.group_by_date([single(), also], [~D[2026-04-15]])

      assert Enum.sort_by(grouped[~D[2026-04-15]], & &1.id) ==
               Enum.sort_by([single(), also], & &1.id)
    end
  end
end
