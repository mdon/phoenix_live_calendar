defmodule LiveCalendar.Views.WeekGridTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import LiveCalendar.Views.WeekGrid

  alias LiveCalendar.Event

  defp render(content), do: rendered_to_string(content)

  describe "week_grid/1" do
    test "renders week grid structure" do
      dates = [
        ~D[2026-03-30],
        ~D[2026-03-31],
        ~D[2026-04-01],
        ~D[2026-04-02],
        ~D[2026-04-03],
        ~D[2026-04-04],
        ~D[2026-04-05]
      ]

      assigns = %{dates: dates}

      html = render(~H"<.week_grid dates={@dates} />")

      assert html =~ "cal-week-grid"
      assert html =~ "cal-week-header"
      assert html =~ "cal-week-body"
    end

    test "renders day column headers" do
      dates = [~D[2026-04-01], ~D[2026-04-02], ~D[2026-04-03]]
      assigns = %{dates: dates}

      html = render(~H"<.week_grid dates={@dates} />")

      assert html =~ "cal-day-column-header"
      assert html =~ "Wed"
      assert html =~ "Thu"
      assert html =~ "Fri"
    end

    test "renders time slots" do
      dates = [~D[2026-04-01]]
      assigns = %{dates: dates}

      html =
        render(
          ~H"<.week_grid dates={@dates} min_time={~T[09:00:00]} max_time={~T[12:00:00]} slot_duration={60} />"
        )

      assert html =~ "cal-time-slot"
      assert html =~ "09:00"
      assert html =~ "10:00"
      assert html =~ "11:00"
    end

    test "renders all-day row" do
      dates = [~D[2026-04-01]]
      assigns = %{dates: dates}

      html = render(~H"<.week_grid dates={@dates} />")

      assert html =~ "cal-all-day-row"
      assert html =~ "All day"
    end

    test "hides all-day row when disabled" do
      dates = [~D[2026-04-01]]
      assigns = %{dates: dates}

      html = render(~H"<.week_grid dates={@dates} show_all_day_row={false} />")

      refute html =~ "cal-all-day-row"
    end

    test "renders timed events positioned" do
      dates = [~D[2026-04-01]]

      event = %Event{
        id: "1",
        start: ~U[2026-04-01 10:00:00Z],
        end: ~U[2026-04-01 11:00:00Z],
        title: "Meeting"
      }

      assigns = %{dates: dates, events: [event]}

      html = render(~H"<.week_grid dates={@dates} events={@events} />")

      assert html =~ "Meeting"
      assert html =~ "top:"
      assert html =~ "height:"
    end

    test "renders all-day events in header" do
      dates = [~D[2026-04-01]]
      event = %Event{id: "1", start: ~D[2026-04-01], title: "Holiday", all_day: true}
      assigns = %{dates: dates, events: [event]}

      html = render(~H"<.week_grid dates={@dates} events={@events} />")

      assert html =~ "Holiday"
      assert html =~ "cal-all-day-row"
      assert html =~ "cal-spanning-bar"
    end

    test "renders in 12h format" do
      dates = [~D[2026-04-01]]
      assigns = %{dates: dates}

      html =
        render(
          ~H"<.week_grid dates={@dates} min_time={~T[09:00:00]} max_time={~T[15:00:00]} time_format={:h12} />"
        )

      assert html =~ "AM"
      assert html =~ "PM"
    end

    test "renders with custom slot height" do
      dates = [~D[2026-04-01]]
      assigns = %{dates: dates}

      html =
        render(
          ~H"<.week_grid dates={@dates} min_time={~T[09:00:00]} max_time={~T[10:00:00]} slot_height=\"5rem\" />"
        )

      assert html =~ "height: 5rem"
    end

    test "highlights today column" do
      today = Date.utc_today()
      assigns = %{dates: [today], today: today}

      html = render(~H"<.week_grid dates={@dates} today={@today} />")

      assert html =~ "bg-primary/5"
    end
  end
end
