defmodule PhoenixLiveCalendar.Views.MonthGridTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Views.MonthGrid

  alias PhoenixLiveCalendar.Event

  defp render(content), do: rendered_to_string(content)

  # Five bars that all overlap → slots 0..4 on every shared day.
  defp overlapping_bars do
    for i <- 1..5 do
      %Event{
        id: "e#{i}",
        start: ~D[2026-04-06],
        end: ~D[2026-04-13],
        title: "Ev#{i}",
        all_day: true
      }
    end
  end

  describe "month_grid/1" do
    test "renders month grid structure" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} />")

      assert html =~ "cal-month-grid"
      assert html =~ "cal-month-header"
      assert html =~ "cal-week-row"
      assert html =~ "cal-day-cell"
    end

    test "columns use minmax(0, 1fr) so a wide cell can't make a row overflow" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} />")

      # Plain `1fr` is `minmax(auto, 1fr)`: nowrap content wider than 1/7 would
      # blow the row past the viewport on phones. minmax(0, 1fr) lets it shrink.
      assert html =~ "minmax(0, 1fr)"
      refute html =~ "repeat(7, 1fr)"
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

    test "day headers carry a single-letter (mobile) and a short (desktop) variant" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} week_start={1} />")

      # Narrow letters show only on phones; short names only from `sm` up.
      assert html =~ ~s(class="sm:hidden")
      assert html =~ ~s(class="hidden sm:inline")
      assert html =~ "Mon"
      # Screen readers still get the full day name regardless of breakpoint.
      assert html =~ ~s(aria-label="Monday")
    end

    test "renders with Sunday week start" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} week_start={7} />")

      # First column header should be Sunday — it renders before Monday.
      assert html =~ "Sun"
      assert :binary.match(html, "Sun") |> elem(0) < :binary.match(html, "Mon") |> elem(0)
    end
  end

  describe "multi-day event slot alignment" do
    # A and B overlap on 04-07, so A takes slot 0 and B takes slot 1. On 04-08
    # A has ended, leaving slot 0 empty under B — that gap must render a spacer
    # so B stays on its own row (instead of shifting up to slot 0).
    test "renders a spacer for an empty leading slot under a later-row bar" do
      events = [
        %Event{id: "a", start: ~D[2026-04-06], end: ~D[2026-04-08], title: "Alpha", all_day: true},
        %Event{id: "b", start: ~D[2026-04-07], end: ~D[2026-04-10], title: "Bravo", all_day: true}
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "cal-multiday-spacer"
      assert html =~ "cal-multiday-bar"
      assert html =~ "Alpha"
      assert html =~ "Bravo"
    end

    test "renders no spacer for a single multi-day event (trailing slots dropped)" do
      events = [
        %Event{id: "a", start: ~D[2026-04-06], end: ~D[2026-04-09], title: "Alpha", all_day: true}
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "cal-multiday-bar"
      refute html =~ "cal-multiday-spacer"
    end

    test "labels a bar that started before the visible month (at each week start)" do
      # Starts 2026-03-20, well before the April grid, so its true start day is
      # never in view — the label must still appear via the week-start rule.
      events = [
        %Event{
          id: "cont",
          start: ~D[2026-03-20],
          end: ~D[2026-04-20],
          title: "Continues",
          all_day: true
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "Continues"
    end

    test "renders two non-overlapping multi-day events that share a slot in one week" do
      # Both fall in the Apr 6–12 week and don't overlap (Alpha 6–7, Bravo 9–10),
      # so the greedy packer gives both slot 0. Both bars must still render.
      events = [
        %Event{
          id: "a",
          start: ~D[2026-04-06],
          end: ~D[2026-04-08],
          title: "AlphaSlot",
          all_day: true
        },
        %Event{
          id: "b",
          start: ~D[2026-04-09],
          end: ~D[2026-04-11],
          title: "BravoSlot",
          all_day: true
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "AlphaSlot"
      assert html =~ "BravoSlot"
    end

    test "applies extra.highlight class to the in-range day segments of a bar" do
      events = [
        %Event{
          id: "od",
          start: ~D[2026-04-06],
          end: ~D[2026-04-13],
          title: "Overdue",
          all_day: true,
          extra: %{highlight: %{from: ~D[2026-04-10], class: "pk-overdue"}}
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "pk-overdue"
    end

    test "omits extra.highlight class when the range does not intersect the bar" do
      events = [
        %Event{
          id: "od",
          start: ~D[2026-04-06],
          end: ~D[2026-04-08],
          title: "NotYet",
          all_day: true,
          extra: %{highlight: %{from: ~D[2026-04-20], class: "pk-overdue"}}
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      refute html =~ "pk-overdue"
    end

    test "exposes a per-day --pk-hl-index on highlighted segments (for wave/gradient)" do
      events = [
        %Event{
          id: "od",
          start: ~D[2026-04-06],
          end: ~D[2026-04-13],
          title: "Overdue",
          all_day: true,
          extra: %{highlight: %{from: ~D[2026-04-10], class: "pk-overdue"}}
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      # Highlight starts 04-10, so 04-10/11/12 carry indices 0/1/2.
      assert html =~ "--pk-hl-index: 0"
      assert html =~ "--pk-hl-index: 1"
      assert html =~ "--pk-hl-index: 2"
    end

    test "exposes --pk-hl-count when the highlight has a bounded `to`" do
      events = [
        %Event{
          id: "od",
          start: ~D[2026-04-06],
          end: ~D[2026-04-13],
          title: "Overdue",
          all_day: true,
          # 04-10 .. 04-13 exclusive = 3 days
          extra: %{highlight: %{from: ~D[2026-04-10], to: ~D[2026-04-13], class: "pk-overdue"}}
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "--pk-hl-count: 3"
    end

    test "exposes the absolute date as --pk-hl-day (for cross-bar date sync)" do
      events = [
        %Event{
          id: "od",
          start: ~D[2026-04-06],
          end: ~D[2026-04-13],
          title: "Overdue",
          all_day: true,
          extra: %{highlight: %{from: ~D[2026-04-10], class: "pk-overdue"}}
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "--pk-hl-day: #{Date.to_gregorian_days(~D[2026-04-10])}"
    end

    test "extra.slot_priority packs lower-priority events into top slots" do
      # Both start 04-06 and overlap. By natural order (longest first) A (longer)
      # would take slot 0; slot_priority 0 on B overrides that, so B lands on top.
      events = [
        %Event{
          id: "a",
          start: ~D[2026-04-06],
          end: ~D[2026-04-13],
          title: "AaaPrio",
          all_day: true,
          extra: %{slot_priority: 1}
        },
        %Event{
          id: "b",
          start: ~D[2026-04-06],
          end: ~D[2026-04-10],
          title: "BbbPrio",
          all_day: true,
          extra: %{slot_priority: 0}
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      # Both label on their shared start cell, in slot order → B (slot 0) first.
      {b_pos, _} = :binary.match(html, "BbbPrio")
      {a_pos, _} = :binary.match(html, "AaaPrio")
      assert b_pos < a_pos
    end

    test "appends a multi-day event's :class to its bar (consumer styling hook)" do
      events = [
        %Event{
          id: "a",
          start: ~D[2026-04-06],
          end: ~D[2026-04-10],
          title: "Late",
          all_day: true,
          class: "pk-custom-bar-style"
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "pk-custom-bar-style"
    end
  end

  describe "expand_cells" do
    test "defaults to fixed-height, overflow-clipped day cells" do
      assigns = %{date: ~D[2026-04-01]}
      html = render(~H"<.month_grid date={@date} />")

      # fixed height tier + clipping
      assert html =~ "lg:h-32"
    end

    test "expand_cells grows day cells to fit (min-height, no clip)" do
      assigns = %{date: ~D[2026-04-01]}
      html = render(~H"<.month_grid date={@date} expand_cells={true} />")

      assert html =~ "lg:min-h-32"
      # no fixed-height tier on the cell (so it can grow with its bars)
      refute html =~ "lg:h-32"
    end
  end

  describe "max_multiday" do
    test "nil (default) shows every multi-day bar with no overflow link" do
      assigns = %{date: ~D[2026-04-01], events: overlapping_bars()}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "Ev5"
      refute html =~ "cal-more-link"
    end

    test "caps the bars and folds the rest into the day's +N more" do
      assigns = %{date: ~D[2026-04-01], events: overlapping_bars()}
      html = render(~H"<.month_grid date={@date} events={@events} max_multiday={2} />")

      assert html =~ "cal-more-link"
    end
  end
end
