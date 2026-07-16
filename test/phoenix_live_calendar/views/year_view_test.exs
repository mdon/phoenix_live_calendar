defmodule PhoenixLiveCalendar.Views.YearViewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Views.YearView

  defp render(content), do: rendered_to_string(content)

  describe "year_view/1" do
    test "renders 12 mini calendars" do
      assigns = %{year: 2026}

      html = render(~H"<.year_view year={@year} />")

      assert html =~ "cal-year-view"
      assert length(Regex.scan(~r/cal-year-month/, html)) == 12
      assert length(Regex.scan(~r/cal-mini-calendar/, html)) == 12
    end

    test "renders all month names" do
      assigns = %{year: 2026}

      html = render(~H"<.year_view year={@year} />")

      for month <- ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) do
        assert html =~ month
      end
    end

    test "renders ARIA grid role" do
      assigns = %{year: 2026}

      html = render(~H"<.year_view year={@year} />")

      assert html =~ ~s(role="grid")
      assert html =~ "2026"
    end

    test "renders with responsive columns" do
      assigns = %{year: 2026}

      html = render(~H"<.year_view year={@year} columns={4} />")

      assert html =~ "grid-cols-2"
      assert html =~ "lg:grid-cols-4"
    end

    test "renders event dot indicators" do
      events = [
        %PhoenixLiveCalendar.Event{id: "1", start: ~D[2026-06-15], title: "Event", all_day: true}
      ]

      assigns = %{year: 2026, events: events}

      html = render(~H"<.year_view year={@year} events={@events} />")

      assert html =~ "rounded-full bg-primary"
    end

    test "day marker colors tint the mini cells (year-scale heatmap)" do
      markers =
        PhoenixLiveCalendar.Heatmap.markers(
          %{~D[2026-06-10] => 20, ~D[2026-06-11] => 100},
          max: 100
        )

      assigns = %{year: 2026, markers: markers}

      html = render(~H"<.year_view year={@year} day_markers={@markers} />")

      assert html =~ "cal-mini-marked"
      assert html =~ "bg-success/20"
      assert html =~ "bg-success"
    end

    test "markers without a custom color leave the mini cells untinted" do
      markers = [
        %PhoenixLiveCalendar.DayMarker{
          id: "notice",
          label: "Notice",
          start_date: ~D[2026-06-10],
          type: :notice
        }
      ]

      assigns = %{year: 2026, markers: markers}

      html = render(~H"<.year_view year={@year} day_markers={@markers} />")

      refute html =~ "cal-mini-marked"
    end
  end
end
