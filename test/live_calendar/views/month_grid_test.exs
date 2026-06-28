defmodule LiveCalendar.Views.MonthGridTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import LiveCalendar.Views.MonthGrid

  alias LiveCalendar.Event

  defp render(content), do: rendered_to_string(content)

  describe "month_grid/1" do
    test "renders month grid structure" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} />")

      assert html =~ "cal-month-grid"
      assert html =~ "cal-month-header"
      assert html =~ "cal-week-row"
      assert html =~ "cal-day-cell"
    end

    test "renders day headers" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} />")

      assert html =~ "cal-day-header"
      assert html =~ "Mon"
      assert html =~ "Tue"
      assert html =~ "Wed"
      assert html =~ "Thu"
      assert html =~ "Fri"
      assert html =~ "Sat"
      assert html =~ "Sun"
    end

    test "renders 6 week rows" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} />")

      assert length(Regex.scan(~r/cal-week-row/, html)) == 6
    end

    test "renders day cells with dates" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} />")

      assert html =~ "cal-day-cell"
      assert html =~ "cal-day-number"
      # All 42 cells have data-date attributes in ISO format
      assert html =~ ~s(data-date="2026-04-01")
      assert html =~ ~s(data-date="2026-04-15")
      assert html =~ ~s(data-date="2026-04-30")
    end

    test "marks today with aria-current" do
      today = Date.utc_today()
      assigns = %{date: today, today: today}

      html = render(~H"<.month_grid date={@date} today={@today} />")

      assert html =~ ~s(aria-current="date")
    end

    test "renders events in cells" do
      event = %Event{id: "1", start: ~D[2026-04-15], title: "Holiday", all_day: true}
      assigns = %{date: ~D[2026-04-01], events: [event]}

      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "Holiday"
      assert html =~ "cal-event"
    end

    test "renders +N more when events exceed max" do
      events =
        for i <- 1..5 do
          %Event{id: "#{i}", start: ~D[2026-04-15], title: "Event #{i}", all_day: true}
        end

      assigns = %{date: ~D[2026-04-01], events: events}

      html = render(~H"<.month_grid date={@date} events={@events} max_events={3} />")

      assert html =~ "+2 more"
      assert html =~ "cal-more-link"
    end

    test "renders week numbers when enabled" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} show_week_numbers={true} />")

      assert html =~ "cal-week-number"
    end

    test "hides week numbers by default" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} />")

      refute html =~ "cal-week-number"
    end

    test "renders day headers with month name" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} />")

      assert html =~ "cal-day-header"
      assert html =~ "Mon"
    end

    test "marks selected date" do
      assigns = %{date: ~D[2026-04-01], selected: ~D[2026-04-15]}

      html = render(~H"<.month_grid date={@date} selected_date={@selected} />")

      assert html =~ ~s(aria-selected="true")
    end

    test "renders with RTL direction" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} dir={:rtl} />")

      assert html =~ ~s(dir="rtl")
    end

    test "renders with custom translations" do
      assigns = %{
        date: ~D[2026-04-01],
        translations: %{day_names_short: %{1 => "Lu", 2 => "Ma", 3 => "Me"}}
      }

      html = render(~H"<.month_grid date={@date} translations={@translations} />")

      assert html =~ "Lu"
      assert html =~ "Ma"
      assert html =~ "Me"
    end

    test "renders with Sunday week start" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} week_start={7} />")

      # First column header should be Sun
      [first_header | _] = Regex.scan(~r/cal-day-header[^>]*>([^<]+)/, html)
      assert hd(first_header) =~ "Sun"
    end
  end
end
