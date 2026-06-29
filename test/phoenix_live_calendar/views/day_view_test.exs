defmodule PhoenixLiveCalendar.Views.DayViewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Views.DayView

  defp render(content), do: rendered_to_string(content)

  describe "day_view/1" do
    test "renders single day time grid" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.day_view date={@date} />")

      assert html =~ "cal-week-grid"
      assert html =~ "Wed"
    end

    test "renders with events" do
      event = %PhoenixLiveCalendar.Event{id: "1", start: ~U[2026-04-01 10:00:00Z], title: "Meeting"}
      assigns = %{date: ~D[2026-04-01], events: [event]}

      html = render(~H"<.day_view date={@date} events={@events} />")

      assert html =~ "Meeting"
    end

    test "has single column" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.day_view date={@date} min_time={~T[09:00:00]} max_time={~T[10:00:00]} />")

      assert html =~ "grid-template-columns: repeat(1, 1fr)"
    end
  end
end
