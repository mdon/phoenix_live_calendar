defmodule PhoenixLiveCalendar.Utils.OverlapLayoutTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils.OverlapLayout

  defp dt(h, m \\ 0), do: DateTime.new!(~D[2026-04-01], Time.new!(h, m, 0))

  defp ev(id, start_h, end_h) do
    %Event{id: id, start: dt(start_h), end: dt(end_h), all_day: false}
  end

  describe "compute/1" do
    test "empty list returns empty map" do
      assert OverlapLayout.compute([]) == %{}
    end

    test "a single event gets column 0 of 1" do
      assert OverlapLayout.compute([ev("a", 9, 10)]) == %{"a" => %{column: 0, total_columns: 1}}
    end

    test "two overlapping events get two distinct columns" do
      layout = OverlapLayout.compute([ev("a", 9, 11), ev("b", 10, 12)])

      assert layout["a"].total_columns == 2
      assert layout["b"].total_columns == 2
      assert Enum.sort([layout["a"].column, layout["b"].column]) == [0, 1]
    end

    test "non-overlapping sequential events each reuse column 0" do
      layout = OverlapLayout.compute([ev("a", 9, 10), ev("b", 10, 11)])

      assert layout["a"] == %{column: 0, total_columns: 1}
      assert layout["b"] == %{column: 0, total_columns: 1}
    end

    test "two overlap + one separate (moduledoc example)" do
      a = ev("a", 9, 10)
      b = %{ev("b", 9, 10) | start: dt(9, 30), end: dt(10, 30)}
      c = ev("c", 11, 12)

      layout = OverlapLayout.compute([a, b, c])

      assert layout["a"].total_columns == 2
      assert layout["b"].total_columns == 2
      assert layout["c"] == %{column: 0, total_columns: 1}
    end

    test "transitively-overlapping events form one group; a free column is reused" do
      # a 9–10, b 9:30–10:30, c 10:15–11 : a–b and b–c overlap, a–c do not.
      a = ev("a", 9, 10)
      b = %{a | id: "b", start: dt(9, 30), end: dt(10, 30)}
      c = %{a | id: "c", start: dt(10, 15), end: dt(11)}

      layout = OverlapLayout.compute([a, b, c])

      # All three share a group (via b), so total_columns is uniform.
      assert layout["a"].total_columns == 2
      assert layout["b"].total_columns == 2
      assert layout["c"].total_columns == 2
      # b sits beside a; c doesn't overlap a, so it reuses column 0.
      assert layout["b"].column == 1
      assert layout["c"].column == 0
    end

    test "all-day events are excluded from the timed layout" do
      ad1 = %Event{id: "x", start: ~D[2026-04-01], end: ~D[2026-04-02], all_day: true}
      ad2 = %Event{id: "y", start: ~D[2026-04-01], end: ~D[2026-04-02], all_day: true}

      assert OverlapLayout.compute([ad1, ad2]) == %{}
    end

    test "mixed all-day + timed only lays out the timed events" do
      ad = %Event{id: "ad", start: ~D[2026-04-01], end: ~D[2026-04-02], all_day: true}
      layout = OverlapLayout.compute([ad, ev("t", 9, 10), ev("u", 9, 10)])

      refute Map.has_key?(layout, "ad")
      assert layout["t"].total_columns == 2
      assert layout["u"].total_columns == 2
    end
  end

  describe "position_style/1" do
    test "column 1 of 3 → one-third width, offset one-third" do
      assert OverlapLayout.position_style(%{column: 1, total_columns: 3}) ==
               "left: 33.33%; width: 33.33%"
    end

    test "column 0 of 2 → left edge, half width" do
      assert OverlapLayout.position_style(%{column: 0, total_columns: 2}) ==
               "left: 0.0%; width: 50.0%"
    end

    test "falls back to full width on a zero/!invalid total" do
      assert OverlapLayout.position_style(%{column: 0, total_columns: 0}) ==
               "left: 0%; width: 100%"

      assert OverlapLayout.position_style(%{}) == "left: 0%; width: 100%"
    end
  end
end
