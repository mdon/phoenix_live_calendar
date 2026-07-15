defmodule PhoenixLiveCalendar.Views.TimelineTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Views.Timeline

  alias PhoenixLiveCalendar.{Event, Resource}

  defp render(content), do: rendered_to_string(content)

  defp night_session do
    %Event{
      id: "night",
      start: ~U[2026-04-01 23:50:00Z],
      end: ~U[2026-04-02 00:20:00Z],
      title: "Late read",
      resource_id: "r1"
    }
  end

  describe "timeline/1" do
    test "renders timeline structure" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources}

      html = render(~H"<.timeline date={@date} resources={@resources} />")

      assert html =~ "cal-timeline"
      assert html =~ "cal-timeline-header"
      assert html =~ "cal-timeline-row"
    end

    test "renders resource labels" do
      resources = [
        %Resource{id: "r1", title: "Room A"},
        %Resource{id: "r2", title: "Room B"}
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources}

      html = render(~H"<.timeline date={@date} resources={@resources} />")

      assert html =~ "Room A"
      assert html =~ "Room B"
      assert html =~ "cal-timeline-resource-label"
    end

    test "renders time headers" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources}

      html =
        render(~H"<.timeline
  date={@date}
  resources={@resources}
  min_time={~T[09:00:00]}
  max_time={~T[12:00:00]}
  slot_duration={60}
/>")

      assert html =~ "09:00"
      assert html =~ "10:00"
      assert html =~ "11:00"
    end

    test "renders resource with color indicator" do
      resources = [%Resource{id: "r1", title: "Room A", color: "bg-accent"}]
      assigns = %{date: ~D[2026-04-01], resources: resources}

      html = render(~H"<.timeline date={@date} resources={@resources} />")

      assert html =~ "bg-accent"
    end

    test "renders events positioned on timeline" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 10:00:00Z],
          end: ~U[2026-04-01 11:00:00Z],
          title: "Meeting",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html = render(~H"<.timeline date={@date} resources={@resources} events={@events} />")

      assert html =~ "Meeting"
      assert html =~ "inset-inline-start:"
      assert html =~ "width:"
    end

    test "renders time slot click targets" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources, on_click: "slot_click"}

      html =
        render(~H"<.timeline
  date={@date}
  resources={@resources}
  on_slot_click={@on_click}
  min_time={~T[09:00:00]}
  max_time={~T[10:00:00]}
/>")

      assert html =~ "cal-timeline-slot"
      assert html =~ "phx-value-resource-id"
    end

    test "renders in 12h format" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources}

      html =
        render(~H"<.timeline
  date={@date}
  resources={@resources}
  min_time={~T[14:00:00]}
  max_time={~T[16:00:00]}
  time_format={:h12}
/>")

      assert html =~ "PM"
    end
  end

  describe "midnight-crossing events" do
    test "clamps to the first day: bar runs from 23:50 to end of day" do
      resources = [%Resource{id: "r1", title: "Series A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources, events: [night_session()]}

      html = render(~H"<.timeline date={@date} resources={@resources} events={@events} />")

      # 23:50 of the default 00:00–23:59:59 window; the 2% width floor pulls
      # the start back from 99.31% so the bar never overruns the track
      assert html =~ "inset-inline-start: 98.0%; width: 2.0%"
    end

    test "clamps to the second day: bar runs from 00:00 to 00:20" do
      resources = [%Resource{id: "r1", title: "Series A"}]
      assigns = %{date: ~D[2026-04-02], resources: resources, events: [night_session()]}

      html = render(~H"<.timeline date={@date} resources={@resources} events={@events} />")

      assert html =~ "inset-inline-start: 0.0%; width: 2.0%"
    end

    test "clamp_to_date={false} restores raw time-of-day positioning" do
      resources = [%Resource{id: "r1", title: "Series A"}]
      assigns = %{date: ~D[2026-04-02], resources: resources, events: [night_session()]}

      html =
        render(
          ~H"<.timeline date={@date} resources={@resources} events={@events} clamp_to_date={false} />"
        )

      # negative-width case: end_pct (00:20) < start_pct (23:50) → 2% floor
      # near the start-time position (pulled back to keep the bar on-track) —
      # the documented pre-clamp behavior
      assert html =~ "inset-inline-start: 98.0%; width: 2.0%"
    end
  end

  describe "filter_to_date" do
    test "events on another date are filtered out by default" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-05 10:00:00Z],
          end: ~U[2026-04-05 11:00:00Z],
          title: "Elsewhere",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html = render(~H"<.timeline date={@date} resources={@resources} events={@events} />")

      refute html =~ "Elsewhere"
    end

    test "filter_to_date={false} still hides off-date events while clamping is on" do
      # clamp_to_date implies the filter: an off-date event's intersection
      # with the date is empty, and one-sided clamping would otherwise
      # fabricate a fictitious 10:00 -> 23:59 bar for it.
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-05 10:00:00Z],
          end: ~U[2026-04-05 11:00:00Z],
          title: "Elsewhere",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html =
        render(
          ~H"<.timeline date={@date} resources={@resources} events={@events} filter_to_date={false} />"
        )

      refute html =~ "Elsewhere"
    end

    test "filter_to_date={false} clamp_to_date={false} renders every event the caller passes" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-05 10:00:00Z],
          end: ~U[2026-04-05 11:00:00Z],
          title: "Elsewhere",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html =
        render(~H"<.timeline
  date={@date}
  resources={@resources}
  events={@events}
  filter_to_date={false}
  clamp_to_date={false}
/>")

      assert html =~ "Elsewhere"
    end
  end

  describe "all-day events" do
    test "an all-day event covering the date renders as a full-width bar" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~D[2026-04-01],
          end: ~D[2026-04-02],
          title: "Offsite",
          all_day: true,
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html = render(~H"<.timeline date={@date} resources={@resources} events={@events} />")

      assert html =~ "Offsite"
      assert html =~ "inset-inline-start: 0.0%; width: 100.0%"
    end
  end

  describe "sticky stacking order" do
    test "the header band paints above the sticky row labels" do
      # header z-30 > labels z-20 > bars/now-line z-10 — otherwise rows
      # scrolling under the sticky header paint their labels over it.
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources}

      html = render(~H"<.timeline date={@date} resources={@resources} />")

      assert html =~ ~r/cal-timeline-header[^"]*sticky top-0[^"]*z-30/
    end
  end

  describe "sticky resource column" do
    test "resource label column is sticky by default" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources}

      html = render(~H"<.timeline date={@date} resources={@resources} />")

      assert html =~ "sticky start-0"
    end

    test "sticky_resource_column={false} disables it" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources}

      html =
        render(~H"<.timeline date={@date} resources={@resources} sticky_resource_column={false} />")

      refute html =~ "sticky start-0"
    end
  end

  describe "now indicator" do
    test "renders a vertical now line when the date is today" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      today = Date.utc_today()
      assigns = %{date: today, today: today, resources: resources}

      html = render(~H"<.timeline date={@date} today={@today} resources={@resources} />")

      assert html =~ "cal-timeline-now-indicator"
    end

    test "renders nothing on other dates" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      today = Date.utc_today()
      assigns = %{date: Date.add(today, 1), today: today, resources: resources}

      html = render(~H"<.timeline date={@date} today={@today} resources={@resources} />")

      refute html =~ "cal-timeline-now-indicator"
    end

    test "the now attr positions the line deterministically" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      today = Date.utc_today()
      assigns = %{date: today, today: today, now: ~T[12:00:00], resources: resources}

      html =
        render(~H"<.timeline date={@date} today={@today} now={@now} resources={@resources} />")

      assert html =~ "cal-timeline-now-indicator"
      assert html =~ "inset-inline-start: 50.0%"
    end

    test "hidden when the current time falls outside the visible window" do
      # Without this the percentage clamps to 0/100 and draws a false line
      # pinned at the window edge.
      resources = [%Resource{id: "r1", title: "Room A"}]
      today = Date.utc_today()
      assigns = %{date: today, today: today, now: ~T[12:00:00], resources: resources}

      html =
        render(~H"<.timeline
  date={@date}
  today={@today}
  now={@now}
  resources={@resources}
  min_time={~T[14:00:00]}
  max_time={~T[18:00:00]}
/>")

      refute html =~ "cal-timeline-now-indicator"
    end

    test "show_now_indicator={false} disables it" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      today = Date.utc_today()
      assigns = %{date: today, today: today, resources: resources}

      html =
        render(
          ~H"<.timeline date={@date} today={@today} resources={@resources} show_now_indicator={false} />"
        )

      refute html =~ "cal-timeline-now-indicator"
    end
  end

  describe "fit_to_events" do
    test "computes the visible window from the events, rounded to surrounding hours" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 08:30:00Z],
          end: ~U[2026-04-01 10:15:00Z],
          title: "Morning read",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html =
        render(~H"<.timeline date={@date} resources={@resources} events={@events} fit_to_events />")

      # window 08:00–11:00 → hour slots 08:00, 09:00, 10:00
      assert html =~ "08:00"
      assert html =~ "10:00"
      refute html =~ "07:00"
      refute html =~ "11:00"

      # 08:30 within the 08:00–11:00 window = 1800/10800
      assert html =~ "inset-inline-start: 16.67%"
    end

    test "falls back when the computed window would be degenerate (zero-duration on the hour)" do
      # floor(09:00) == ceil(09:00) -> an equal window would render a blank
      # axis (0 slots); the guard falls back to the min_time/max_time attrs.
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 09:00:00Z],
          end: ~U[2026-04-01 09:00:00Z],
          title: "Instant",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html =
        render(~H"<.timeline date={@date} resources={@resources} events={@events} fit_to_events />")

      assert html =~ "00:00"
      assert html =~ "12:00"
    end

    test "falls back when an unclamped midnight-crosser inverts the window" do
      # clamp off: window floor(23:50)=23:00 / ceil(00:20)=01:00 is inverted ->
      # guard falls back to the attrs instead of rendering zero slots.
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-02], resources: resources, events: [night_session()]}

      html =
        render(
          ~H"<.timeline date={@date} resources={@resources} events={@events} fit_to_events clamp_to_date={false} />"
        )

      assert html =~ "00:00"
      assert html =~ "12:00"
    end

    test "ignores events without a rendered resource row" do
      # The off-row 06:00 event never draws, so it must not stretch the axis.
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 09:30:00Z],
          end: ~U[2026-04-01 10:30:00Z],
          title: "Mine",
          resource_id: "r1"
        },
        %Event{
          id: "2",
          start: ~U[2026-04-01 06:00:00Z],
          end: ~U[2026-04-01 07:00:00Z],
          title: "Ghost",
          resource_id: "nope"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html =
        render(~H"<.timeline date={@date} resources={@resources} events={@events} fit_to_events />")

      assert html =~ "09:00"
      refute html =~ "06:00"
    end

    test "falls back to min_time/max_time when no timed events render" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources}

      html =
        render(~H"<.timeline
  date={@date}
  resources={@resources}
  fit_to_events
  min_time={~T[09:00:00]}
  max_time={~T[12:00:00]}
/>")

      assert html =~ "09:00"
      refute html =~ "08:00"
    end
  end
end
