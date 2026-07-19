defmodule PhoenixLiveCalendar.Views.MonthGridTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Views.MonthGrid

  alias PhoenixLiveCalendar.Event

  defp render(content), do: rendered_to_string(content)

  defp day_cell_class(html, date) do
    html
    |> Floki.parse_document!()
    |> Floki.find("[data-date='#{date}']")
    |> Floki.attribute("class")
    |> hd()
  end

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
    test "show_weekends: false keeps 5-day rows aligned (no cross-week bleed)" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.month_grid date={@date} show_weekends={false} />")
      doc = Floki.parse_document!(html)

      # No weekend cells at all.
      assert Floki.find(doc, "[data-date='2026-04-04']") == []
      assert Floki.find(doc, "[data-date='2026-04-05']") == []

      # Every week row holds exactly 5 day cells, each row starting on a
      # Monday — the pre-fix 7-chunking pushed Wed/Thu/Fri of later weeks
      # into the wrong rows.
      rows = Floki.find(doc, ".cal-week-row")
      assert rows != []

      for row <- rows do
        cells = Floki.find(row, ".cal-day-cell")
        assert length(cells) == 5

        [first | _] = Floki.attribute(cells, "data-date")
        assert Date.day_of_week(Date.from_iso8601!(first)) == 1
      end
    end

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

    test "today={:none} renders an archive month with no today decorations" do
      today = Date.utc_today()
      assigns = %{date: today}

      html = render(~H"<.month_grid date={@date} today={:none} />")

      refute html =~ ~s(aria-current="date")
      refute html =~ "bg-primary/10"
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

  describe "midnight-crossing timed events" do
    test "a timed event crossing midnight renders as one bar (no duplicate chip ids)" do
      # occupies April 1 (23:30 start) AND April 2 (00:30 end). It spans two
      # dates, so it's now a single continuous bar rather than a per-cell
      # chip in each day — which also sidesteps the old duplicate-DOM-id
      # problem, since bars carry no per-cell id.
      event = %Event{
        id: "night",
        start: ~U[2026-04-01 23:30:00Z],
        end: ~U[2026-04-02 00:30:00Z],
        title: "Night shift handover"
      }

      assigns = %{date: ~D[2026-04-01], events: [event]}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "cal-multiday-bar"
      assert html =~ "Night shift handover"
      # not per-cell chips → no cal-event id (bare or suffixed) at all
      refute html =~ ~s(id="cal-event-night)
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

    test "a multi-day TIMED event renders as one bar, not a chip per day" do
      # a normal (not all-day) event spanning several days — was showing as a
      # separate event in every day cell instead of one continuous bar
      events = [
        %Event{
          id: "trip",
          start: ~U[2026-04-06 09:00:00Z],
          end: ~U[2026-04-13 17:00:00Z],
          title: "Conference trip",
          all_day: false
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      # rendered as a continuous bar, NOT per-day event chips (the only
      # event here, so no cal-event chip should appear at all)
      assert html =~ "cal-multiday-bar"
      assert html =~ "Conference trip"
      refute html =~ "cal-event"
    end

    test "an overnight timed event (10pm→2am) renders as one bar across both days" do
      # it touches two dates, so on the month view it reads as one event —
      # not a separate chip on each day
      events = [
        %Event{
          id: "night",
          start: ~U[2026-04-06 22:00:00Z],
          end: ~U[2026-04-07 02:00:00Z],
          title: "Late shift",
          all_day: false
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "cal-multiday-bar"
      assert html =~ "Late shift"
      refute html =~ "cal-event"
    end

    test "a same-day timed event stays a chip, not a bar" do
      events = [
        %Event{
          id: "mtg",
          start: ~U[2026-04-06 09:00:00Z],
          end: ~U[2026-04-06 10:00:00Z],
          title: "Standup",
          all_day: false
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "Standup"
      refute html =~ "cal-multiday-bar"
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

  describe "respect_hours" do
    # 10th 14:00 -> 12th 10:00 timed bar
    defp hours_event do
      %Event{
        id: "trip",
        start: ~U[2026-04-10 14:00:00Z],
        end: ~U[2026-04-12 10:00:00Z],
        title: "Trip",
        all_day: false
      }
    end

    test "off by default: bars span full cells (no hour geometry)" do
      assigns = %{date: ~D[2026-04-01], events: [hours_event()]}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      assert html =~ "cal-multiday-bar"
      refute html =~ "margin-inline-start:"
      refute html =~ "width:"
    end

    test "on: multi-day bar boundary days trim to the hours occupied" do
      assigns = %{date: ~D[2026-04-01], events: [hours_event()]}
      html = render(~H"<.month_grid date={@date} events={@events} respect_hours={true} />")

      # start day (14:00): offset 14/24 ≈ 58.33%, width the remaining 41.67%
      assert html =~ "margin-inline-start: 58.33%; width: 41.67%"
      # last day (ends 10:00): from the left, 10/24 ≈ 41.67% wide
      assert html =~ "margin-inline-start: 0.0%; width: 41.67%"
    end

    test "on: a multi-day ALL-DAY event still fills whole days (no hours)" do
      events = [
        %Event{id: "vac", start: ~D[2026-04-10], end: ~D[2026-04-13], title: "Vac", all_day: true}
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} respect_hours={true} />")

      assert html =~ "cal-multiday-bar"
      refute html =~ "margin-inline-start:"
      refute html =~ "width:"
    end

    test "on: a single-day timed event becomes a bar positioned by its hours" do
      events = [
        %Event{
          id: "mtg",
          start: ~U[2026-04-06 09:00:00Z],
          end: ~U[2026-04-06 10:30:00Z],
          title: "Standup",
          all_day: false
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} respect_hours={true} />")

      # 09:00 => 37.5% offset; 90 min => 6.25% wide
      assert html =~ "cal-event-timed"
      assert html =~ "margin-inline-start: 37.5%; width: 6.25%"
    end

    test "on: a 5-minute event is floored to a 1-hour-wide bar so it stays visible" do
      events = [
        %Event{
          id: "quick",
          start: ~U[2026-04-06 09:00:00Z],
          end: ~U[2026-04-06 09:05:00Z],
          title: "Quick",
          all_day: false
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} respect_hours={true} />")

      # 5 min ≈ 0.35% would be invisible → floored to 1 hour = 4.17%
      assert html =~ "margin-inline-start: 37.5%; width: 4.17%"
    end

    test "on: a single-day ALL-DAY event stays a full chip (no hours)" do
      events = [%Event{id: "hol", start: ~D[2026-04-06], title: "Holiday", all_day: true}]

      assigns = %{date: ~D[2026-04-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} respect_hours={true} />")

      assert html =~ "Holiday"
      refute html =~ "margin-inline-start:"
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

  describe "slot sharing vs midnight-crossing events" do
    # A occupies Jan 1 AND Jan 2 (last_date = Jan 2, it runs past midnight);
    # B starts on Jan 2. The old overlap check compared A's raw end DATE with
    # strict :gt (exclusive semantics), judged them non-overlapping, and let
    # them share a slot — slot_entry_for_day then found only ONE of them on
    # Jan 2, silently dropping the other's segment.
    test "a midnight-crossing event never shares a slot with an event starting on its last day" do
      events = [
        %Event{
          id: "night-a",
          start: ~U[2026-01-01 22:00:00Z],
          end: ~U[2026-01-02 01:00:00Z],
          title: "Night A"
        },
        %Event{
          id: "night-b",
          start: ~U[2026-01-02 22:00:00Z],
          end: ~U[2026-01-03 01:00:00Z],
          title: "Night B"
        }
      ]

      assigns = %{date: ~D[2026-01-01], events: events}
      html = render(~H"<.month_grid date={@date} events={@events} />")

      bar_ids_on_jan2 =
        html
        |> Floki.parse_document!()
        |> Floki.find("[data-date='2026-01-02'] .cal-multiday-bar")
        |> Floki.attribute("phx-value-event-id")

      assert Enum.sort(bar_ids_on_jan2) == ["night-a", "night-b"]
    end
  end

  describe "day marker styling" do
    alias PhoenixLiveCalendar.DayMarker

    test "a marker's color becomes the cell background, winning over the weekend tint" do
      # 2026-04-04 is a Saturday — without the marker it carries the weekend tint
      markers = [
        %DayMarker{id: "m1", label: "42 min", start_date: ~D[2026-04-04], color: "bg-success/40"}
      ]

      assigns = %{date: ~D[2026-04-01], markers: markers}
      html = render(~H"<.month_grid date={@date} day_markers={@markers} />")

      class = day_cell_class(html, "2026-04-04")
      assert class =~ "bg-success/40"
      assert class =~ "cal-day-marked"
      refute class =~ "bg-base-content/[0.02]"
    end

    test "today and selected keep an inset ring over a custom marker color" do
      markers = [
        %DayMarker{id: "m1", label: "x", start_date: ~D[2026-04-15], color: "bg-success/40"},
        %DayMarker{id: "m2", label: "y", start_date: ~D[2026-04-16], color: "bg-success/70"}
      ]

      assigns = %{date: ~D[2026-04-01], markers: markers}

      html =
        render(~H"<.month_grid
  date={@date}
  day_markers={@markers}
  today={~D[2026-04-15]}
  selected_date={~D[2026-04-16]}
/>")

      today_class = day_cell_class(html, "2026-04-15")
      assert today_class =~ "bg-success/40"
      assert today_class =~ "ring-2 ring-inset ring-primary"
      refute today_class =~ "bg-primary/10"

      selected_class = day_cell_class(html, "2026-04-16")
      assert selected_class =~ "bg-success/70"
      assert selected_class =~ "ring-2 ring-inset ring-secondary"
      refute selected_class =~ "bg-secondary/10"
    end

    test "markers without a custom color keep the type-based cell tint" do
      markers = [
        %DayMarker{
          id: "xmas",
          label: "Christmas",
          start_date: ~D[2026-04-10],
          type: :holiday,
          available: false
        }
      ]

      assigns = %{date: ~D[2026-04-01], markers: markers}
      html = render(~H"<.month_grid date={@date} day_markers={@markers} />")

      class = day_cell_class(html, "2026-04-10")
      assert class =~ "bg-error/8"
      refute class =~ "cal-day-marked"
    end

    test "text_color and class style the label chip, replacing the type defaults" do
      markers = [
        %DayMarker{
          id: "m1",
          label: "Custom",
          start_date: ~D[2026-04-10],
          class: "bg-purple-500",
          text_color: "text-white"
        }
      ]

      assigns = %{date: ~D[2026-04-01], markers: markers}
      html = render(~H"<.month_grid date={@date} day_markers={@markers} />")

      chip_class =
        html
        |> Floki.parse_document!()
        |> Floki.find("[data-date='2026-04-10'] .cal-marker-label")
        |> Floki.attribute("class")
        |> hd()

      assert chip_class =~ "bg-purple-500"
      assert chip_class =~ "text-white"
      refute chip_class =~ "bg-base-200"
    end

    test "show_label: false renders the cell tint with no corner chip" do
      markers = [
        %DayMarker{
          id: "m1",
          label: "42 min",
          start_date: ~D[2026-04-10],
          color: "bg-success/40",
          show_label: false
        }
      ]

      assigns = %{date: ~D[2026-04-01], markers: markers}
      html = render(~H"<.month_grid date={@date} day_markers={@markers} />")

      assert day_cell_class(html, "2026-04-10") =~ "bg-success/40"

      chips =
        html
        |> Floki.parse_document!()
        |> Floki.find("[data-date='2026-04-10'] .cal-marker-label")

      assert chips == []
    end

    test "a nil label is tolerated and renders no chip" do
      markers = [
        %DayMarker{id: "m1", label: nil, start_date: ~D[2026-04-10], color: "bg-success/40"}
      ]

      assigns = %{date: ~D[2026-04-01], markers: markers}
      html = render(~H"<.month_grid date={@date} day_markers={@markers} />")

      assert day_cell_class(html, "2026-04-10") =~ "bg-success/40"

      chips =
        html
        |> Floki.parse_document!()
        |> Floki.find("[data-date='2026-04-10'] .cal-marker-label")

      assert chips == []
    end

    test "a custom color keeps the semantic marker class on the cell" do
      # Consumer CSS/tests key off cal-day-holiday etc.; the color replaces
      # only the bg utility, never the semantic hook.
      markers = [
        %DayMarker{
          id: "xmas",
          label: "Christmas",
          start_date: ~D[2026-04-10],
          type: :holiday,
          available: false,
          color: "bg-error/40"
        }
      ]

      assigns = %{date: ~D[2026-04-01], markers: markers}
      html = render(~H"<.month_grid date={@date} day_markers={@markers} />")

      class = day_cell_class(html, "2026-04-10")
      assert class =~ "cal-day-holiday"
      assert class =~ "bg-error/40"
      refute class =~ "bg-error/8"
    end

    test "the id attr prefixes ticker ids so two grids on one page can't collide" do
      markers = [
        %DayMarker{id: "m1", label: "Alpha", start_date: ~D[2026-04-06]},
        %DayMarker{id: "m2", label: "Beta", start_date: ~D[2026-04-06]}
      ]

      assigns = %{date: ~D[2026-04-01], markers: markers, id_a: "cal-a", id_b: "cal-b"}

      html_a = render(~H"<.month_grid id={@id_a} date={@date} day_markers={@markers} />")
      html_b = render(~H"<.month_grid id={@id_b} date={@date} day_markers={@markers} />")

      [id_a] =
        html_a
        |> Floki.parse_document!()
        |> Floki.find(".cal-marker-ticker")
        |> Floki.attribute("id")

      [id_b] =
        html_b
        |> Floki.parse_document!()
        |> Floki.find(".cal-marker-ticker")
        |> Floki.attribute("id")

      assert String.starts_with?(id_a, "cal-a-ticker-")
      assert String.starts_with?(id_b, "cal-b-ticker-")
      assert id_a != id_b
    end

    test "ticker ids are unique across the days of a multi-day marker" do
      # Two markers covering the same two days → each day renders a ticker.
      # The id must differ per day, or a multi-day marker produces duplicate
      # DOM ids (invalid HTML, misbinding MarkerTicker hooks).
      markers = [
        %DayMarker{
          id: "m1",
          label: "Alpha",
          start_date: ~D[2026-04-06],
          end_date: ~D[2026-04-08]
        },
        %DayMarker{
          id: "m2",
          label: "Beta",
          start_date: ~D[2026-04-06],
          end_date: ~D[2026-04-08]
        }
      ]

      assigns = %{date: ~D[2026-04-01], markers: markers}
      html = render(~H"<.month_grid date={@date} day_markers={@markers} />")

      ticker_ids =
        html
        |> Floki.parse_document!()
        |> Floki.find(".cal-marker-ticker")
        |> Floki.attribute("id")

      assert length(ticker_ids) == 2
      assert length(Enum.uniq(ticker_ids)) == 2
      assert Enum.any?(ticker_ids, &(&1 =~ "2026-04-06"))
      assert Enum.any?(ticker_ids, &(&1 =~ "2026-04-07"))
    end
  end
end
