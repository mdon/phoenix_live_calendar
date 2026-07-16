defmodule PhoenixLiveCalendar.Views.WeekGridTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Views.WeekGrid

  alias PhoenixLiveCalendar.Event

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
        render(~H"""
        <.week_grid dates={@dates} min_time={~T[09:00:00]} max_time={~T[10:00:00]} slot_height="5rem" />
        """)

      assert html =~ "height: 5rem"
    end

    test "highlights today column" do
      today = Date.utc_today()
      assigns = %{dates: [today], today: today}

      html = render(~H"<.week_grid dates={@dates} today={@today} />")

      assert html =~ "bg-primary/5"
    end
  end

  describe "all-day lane packing" do
    defp april_week, do: Enum.map(6..12, &Date.new!(2026, 4, &1))

    test "overlapping all-day bars get distinct explicit lanes" do
      events = [
        %Event{id: "a", start: ~D[2026-04-06], end: ~D[2026-04-09], title: "Alpha", all_day: true},
        %Event{id: "b", start: ~D[2026-04-08], end: ~D[2026-04-11], title: "Bravo", all_day: true}
      ]

      assigns = %{dates: april_week(), events: events}
      html = render(~H"<.week_grid dates={@dates} events={@events} />")

      assert html =~ "grid-row: 1"
      assert html =~ "grid-row: 2"
    end

    test "non-overlapping all-day bars share the first lane" do
      events = [
        %Event{id: "a", start: ~D[2026-04-06], end: ~D[2026-04-08], title: "Alpha", all_day: true},
        %Event{id: "b", start: ~D[2026-04-09], end: ~D[2026-04-11], title: "Bravo", all_day: true}
      ]

      assigns = %{dates: april_week(), events: events}
      html = render(~H"<.week_grid dates={@dates} events={@events} />")

      assert html =~ "grid-row: 1"
      refute html =~ "grid-row: 2"
    end
  end

  describe "day markers" do
    test "labeled markers render as chips under the day header" do
      markers = [
        %PhoenixLiveCalendar.DayMarker{
          id: "xmas",
          label: "Christmas",
          start_date: ~D[2026-04-08],
          type: :holiday,
          available: false
        }
      ]

      assigns = %{dates: Enum.map(6..12, &Date.new!(2026, 4, &1)), markers: markers}
      html = render(~H"<.week_grid dates={@dates} day_markers={@markers} />")

      assert html =~ "cal-marker-label"
      assert html =~ "Christmas"
      # the type tint lands on the day column, with its semantic hook
      assert html =~ "cal-day-holiday"
      assert html =~ "bg-error/8"
    end

    test "a custom marker color tints the day column" do
      markers = [
        %PhoenixLiveCalendar.DayMarker{
          id: "hm",
          label: "42 min",
          start_date: ~D[2026-04-08],
          color: "bg-success/40",
          show_label: false
        }
      ]

      assigns = %{dates: Enum.map(6..12, &Date.new!(2026, 4, &1)), markers: markers}
      html = render(~H"<.week_grid dates={@dates} day_markers={@markers} />")

      assert html =~ "cal-day-marked"
      assert html =~ "bg-success/40"
      # show_label: false -> tint only, no chip
      refute html =~ "cal-marker-label"
    end
  end

  describe "event detail mode" do
    test "week blocks show title, time range and location by default" do
      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-08 10:00:00Z],
          end: ~U[2026-04-08 11:30:00Z],
          title: "Reading session",
          location: "Library",
          resource_id: nil
        }
      ]

      assigns = %{dates: [~D[2026-04-08]], events: events}
      html = render(~H"<.week_grid dates={@dates} events={@events} />")

      assert html =~ "cal-event-detail"
      assert html =~ "10:00"
      assert html =~ "11:30"
      assert html =~ "Library"
    end

    test "event_detail={false} restores the single-line layout" do
      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-08 10:00:00Z],
          end: ~U[2026-04-08 11:30:00Z],
          title: "Reading session",
          location: "Library"
        }
      ]

      assigns = %{dates: [~D[2026-04-08]], events: events}
      html = render(~H"<.week_grid dates={@dates} events={@events} event_detail={false} />")

      refute html =~ "cal-event-detail"
      refute html =~ "Library"
      assert html =~ "Reading session"
    end
  end

  describe "responsive headers" do
    test "day names carry a narrow (phone) and short (desktop) variant" do
      assigns = %{dates: [~D[2026-04-08]]}
      html = render(~H"<.week_grid dates={@dates} />")

      assert html =~ ~s(class="sm:hidden")
      assert html =~ "hidden sm:inline"
      assert html =~ ~s(aria-label="Wednesday")
    end

    test "columns use minmax(0, 1fr) so wide bars can't blow the row" do
      assigns = %{dates: Enum.map(6..12, &Date.new!(2026, 4, &1))}
      html = render(~H"<.week_grid dates={@dates} />")

      assert html =~ "minmax(0, 1fr)"
      refute html =~ "repeat(7, 1fr)"
    end
  end

  describe "instance-scoped event ids" do
    test "the id attr prefixes event DOM ids so two views sharing events can't collide" do
      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-08 10:00:00Z],
          end: ~U[2026-04-08 11:00:00Z],
          title: "Meeting"
        }
      ]

      assigns = %{dates: [~D[2026-04-08]], events: events, id_a: "top", id_b: "bottom"}

      html_a = render(~H"<.week_grid id={@id_a} dates={@dates} events={@events} />")
      html_b = render(~H"<.week_grid id={@id_b} dates={@dates} events={@events} />")

      assert html_a =~ ~s(id="cal-event-1-top-2026-04-08")
      assert html_b =~ ~s(id="cal-event-1-bottom-2026-04-08")
    end
  end

  describe "per-day window clamping" do
    test "a midnight-crossing event renders its real segment on each day" do
      # 21:30 -> 01:00 with a full-day window: Saturday shows 21:30..24:00,
      # Sunday shows 00:00..01:00 at the top — not a phantom sliver at 21:30
      # on both days (the raw time-of-day bug).
      events = [
        %Event{
          id: "binge",
          start: ~U[2026-04-11 21:30:00Z],
          end: ~U[2026-04-12 01:00:00Z],
          title: "Late binge"
        }
      ]

      assigns = %{dates: [~D[2026-04-11], ~D[2026-04-12]], events: events}
      html = render(~H"<.week_grid dates={@dates} events={@events} />")

      blocks =
        html
        |> Floki.parse_document!()
        |> Floki.find("[data-date] .cal-event")

      assert length(blocks) == 2
      # Saturday segment starts at 21:30 of a 24h axis (~89.58%)
      assert html =~ "top: 89.58"
      # Sunday segment starts at the very top
      assert html =~ "top: 0.0%"
    end

    test "the off-window part of a midnight-crosser is dropped, not floored" do
      # Window 06:00-22:00: Saturday shows 21:30..22:00; Sunday's 00:00-01:00
      # portion is entirely before the window -> no block at all.
      events = [
        %Event{
          id: "binge",
          start: ~U[2026-04-11 21:30:00Z],
          end: ~U[2026-04-12 01:00:00Z],
          title: "Late binge"
        }
      ]

      assigns = %{dates: [~D[2026-04-11], ~D[2026-04-12]], events: events}

      html =
        render(~H"<.week_grid
  dates={@dates}
  events={@events}
  min_time={~T[06:00:00]}
  max_time={~T[22:00:00]}
/>")

      doc = Floki.parse_document!(html)
      sat = Floki.find(doc, "[data-date='2026-04-11'] .cal-event")
      sun = Floki.find(doc, "[data-date='2026-04-12'] .cal-event")

      assert length(sat) == 1
      assert sun == []
    end

    test "an event entirely outside the visible window renders nothing" do
      events = [
        %Event{
          id: "early",
          start: ~U[2026-04-11 05:00:00Z],
          end: ~U[2026-04-11 05:30:00Z],
          title: "Early jog"
        }
      ]

      assigns = %{dates: [~D[2026-04-11]], events: events}

      html =
        render(~H"<.week_grid
  dates={@dates}
  events={@events}
  min_time={~T[06:00:00]}
  max_time={~T[22:00:00]}
/>")

      refute html =~ "Early jog"
    end
  end
end
