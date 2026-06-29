defmodule PhoenixLiveCalendar.Components.MiniCalendarTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Components.MiniCalendar

  defp render(content), do: rendered_to_string(content)

  describe "mini_calendar/1" do
    test "renders month header" do
      assigns = %{date: ~D[2026-04-15]}

      html = render(~H"<.mini_calendar date={@date} />")

      assert html =~ "Apr 2026"
      assert html =~ "cal-mini-calendar"
    end

    test "renders day name headers" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.mini_calendar date={@date} />")

      assert html =~ "cal-mini-day-header"
      # Narrow day names rendered in header cells
      for name <- ~w(M T W F S) do
        assert html =~ name
      end
    end

    test "renders grid with proper ARIA roles" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.mini_calendar date={@date} />")

      assert html =~ ~s(role="grid")
      assert html =~ ~s(role="row")
      assert html =~ ~s(role="columnheader")
      assert html =~ ~s(role="gridcell")
    end

    test "renders all days of month" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.mini_calendar date={@date} />")

      # April has 30 days — each appears in a cal-mini-date span
      for day <- 1..30 do
        assert html =~ ">\n            #{day}\n"
      end
    end

    test "highlights today" do
      assigns = %{date: Date.utc_today(), today: Date.utc_today()}

      html = render(~H"<.mini_calendar date={@date} today={@today} />")

      assert html =~ "bg-primary"
      assert html =~ ~s(aria-current="date")
    end

    test "marks selected date" do
      assigns = %{date: ~D[2026-04-01], selected_date: ~D[2026-04-15]}

      html = render(~H"<.mini_calendar date={@date} selected_date={@selected_date} />")

      assert html =~ ~s(aria-selected="true")
    end

    test "renders event dot indicators" do
      events_by_date = %{~D[2026-04-15] => [%{id: "1"}, %{id: "2"}]}
      assigns = %{date: ~D[2026-04-01], events_by_date: events_by_date}

      html = render(~H"<.mini_calendar date={@date} events_by_date={@events_by_date} />")

      assert html =~ "rounded-full bg-primary"
    end

    test "hides header when show_header is false" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.mini_calendar date={@date} show_header={false} />")

      refute html =~ "cal-mini-header"
    end

    test "renders clickable dates when on_date_click set" do
      assigns = %{date: ~D[2026-04-01], on_click: "date_click"}

      html = render(~H"<.mini_calendar date={@date} on_date_click={@on_click} />")

      assert html =~ "phx-click"
      assert html =~ "phx-value-date"
    end

    test "renders non-clickable dates when on_date_click not set" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.mini_calendar date={@date} />")

      refute html =~ "phx-click"
    end

    test "respects week_start" do
      assigns = %{date: ~D[2026-04-01]}

      html_mon = render(~H"<.mini_calendar date={@date} week_start={1} />")
      html_sun = render(~H"<.mini_calendar date={@date} week_start={7} />")

      # Different ordering of day headers
      refute html_mon == html_sun
    end
  end
end
