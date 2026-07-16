defmodule PhoenixLiveCalendar.Views.NDayViewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Views.NDayView

  defp render(content), do: rendered_to_string(content)

  describe "n_day_view/1" do
    test "renders correct number of day columns" do
      assigns = %{date: ~D[2026-04-01], days: 4}

      html = render(~H"<.n_day_view date={@date} days={@days} />")

      assert html =~ "grid-template-columns: repeat(4, minmax(0, 1fr))"
    end

    test "renders 3-day view" do
      assigns = %{date: ~D[2026-04-01], days: 3}

      html = render(~H"<.n_day_view date={@date} days={@days} />")

      assert html =~ "Wed"
      assert html =~ "Thu"
      assert html =~ "Fri"
    end

    test "renders with events" do
      event = %PhoenixLiveCalendar.Event{id: "1", start: ~U[2026-04-02 10:00:00Z], title: "Meeting"}
      assigns = %{date: ~D[2026-04-01], days: 4, events: [event]}

      html = render(~H"<.n_day_view date={@date} days={@days} events={@events} />")

      assert html =~ "Meeting"
    end
  end
end
