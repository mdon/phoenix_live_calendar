defmodule PhoenixLiveCalendar.HeatmapTest do
  use ExUnit.Case, async: true

  alias PhoenixLiveCalendar.{DayMarker, Heatmap}

  describe "markers/2 — linear scale" do
    test "buckets values into the palette by value/max" do
      data = %{
        ~D[2026-04-01] => 1,
        ~D[2026-04-02] => 50,
        ~D[2026-04-03] => 100
      }

      markers = Heatmap.markers(data)
      by_date = Map.new(markers, &{&1.start_date, &1})

      assert by_date[~D[2026-04-01]].color == "bg-success/20"
      assert by_date[~D[2026-04-02]].color == "bg-success/60"
      assert by_date[~D[2026-04-03]].color == "bg-success"
    end

    test "an explicit :max caps the scale" do
      data = %{~D[2026-04-01] => 10}

      [marker] = Heatmap.markers(data, max: 100)
      assert marker.color == "bg-success/20"

      [marker] = Heatmap.markers(data, max: 10)
      assert marker.color == "bg-success"
    end

    test "values above :max clamp to the top bucket" do
      [marker] = Heatmap.markers(%{~D[2026-04-01] => 500}, max: 100)
      assert marker.color == "bg-success"
    end
  end

  describe "markers/2 — quantile scale" do
    test "buckets by rank so an outlier doesn't wash out the rest" do
      data = %{
        ~D[2026-04-01] => 1,
        ~D[2026-04-02] => 2,
        ~D[2026-04-03] => 3,
        ~D[2026-04-04] => 4,
        ~D[2026-04-05] => 1000
      }

      markers = Heatmap.markers(data, scale: :quantile)
      by_date = Map.new(markers, &{&1.start_date, &1})

      # Linear would put 1..4 all in the bottom bucket; quantile spreads them.
      assert by_date[~D[2026-04-01]].color == "bg-success/20"
      assert by_date[~D[2026-04-03]].color == "bg-success/60"
      assert by_date[~D[2026-04-05]].color == "bg-success"

      distinct = markers |> Enum.map(& &1.color) |> Enum.uniq() |> length()
      assert distinct == 5
    end
  end

  describe "markers/2 — shaping" do
    test "skips zero, negative, and non-numeric values" do
      data = %{
        ~D[2026-04-01] => 0,
        ~D[2026-04-02] => -5,
        ~D[2026-04-03] => nil,
        ~D[2026-04-04] => 42
      }

      assert [%DayMarker{start_date: ~D[2026-04-04]}] = Heatmap.markers(data)
    end

    test "accepts a list of pairs and returns date-sorted markers" do
      data = [{~D[2026-04-05], 3}, {~D[2026-04-01], 7}]

      assert [%{start_date: ~D[2026-04-01]}, %{start_date: ~D[2026-04-05]}] =
               Heatmap.markers(data)
    end

    test "labels default to the value, hidden by default" do
      [marker] = Heatmap.markers(%{~D[2026-04-01] => 42})

      assert marker.label == "42"
      assert marker.show_label == false
      assert marker.extra.value == 42
    end

    test "a custom label fun and show_label are honored" do
      [marker] =
        Heatmap.markers(%{~D[2026-04-01] => 42},
          label: fn v -> "#{v} min read" end,
          show_label: true
        )

      assert marker.label == "42 min read"
      assert marker.show_label == true
    end

    test "label: nil produces label-less markers" do
      [marker] = Heatmap.markers(%{~D[2026-04-01] => 42}, label: nil)
      assert marker.label == nil
    end

    test "ids are prefix-date scoped" do
      [marker] = Heatmap.markers(%{~D[2026-04-01] => 1}, id_prefix: "reading")
      assert marker.id == "reading-2026-04-01"
    end

    test "a custom palette drives the buckets" do
      data = %{~D[2026-04-01] => 1, ~D[2026-04-02] => 10}

      markers = Heatmap.markers(data, palette: ["bg-info/30", "bg-info"])
      by_date = Map.new(markers, fn m -> {m.start_date, m.color} end)

      assert by_date[~D[2026-04-01]] == "bg-info/30"
      assert by_date[~D[2026-04-02]] == "bg-info"
    end

    test "an empty palette raises" do
      assert_raise ArgumentError, fn ->
        Heatmap.markers(%{~D[2026-04-01] => 1}, palette: [])
      end
    end

    test "empty data returns no markers" do
      assert Heatmap.markers(%{}) == []
    end
  end

  describe "end-to-end with the month grid" do
    import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
    import Phoenix.Component, only: [sigil_H: 2]

    test "heatmap markers tint the month cells without label chips" do
      markers = Heatmap.markers(%{~D[2026-04-10] => 30, ~D[2026-04-11] => 90}, max: 100)
      assigns = %{date: ~D[2026-04-01], markers: markers}

      html =
        rendered_to_string(
          ~H"<PhoenixLiveCalendar.Views.MonthGrid.month_grid date={@date} day_markers={@markers} />"
        )

      doc = Floki.parse_document!(html)

      [cell_class] = doc |> Floki.find("[data-date='2026-04-10']") |> Floki.attribute("class")
      assert cell_class =~ "bg-success/40"

      [cell_class] = doc |> Floki.find("[data-date='2026-04-11']") |> Floki.attribute("class")
      assert cell_class =~ "bg-success"

      assert Floki.find(doc, ".cal-marker-label") == []
    end
  end
end
