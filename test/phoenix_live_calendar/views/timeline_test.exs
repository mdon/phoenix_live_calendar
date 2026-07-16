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

      doc = Floki.parse_document!(html)
      [header_class] = doc |> Floki.find(".cal-timeline-header") |> Floki.attribute("class")

      assert header_class =~ "sticky"
      assert header_class =~ "top-0"
      assert header_class =~ "z-30"
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

  describe "instance-scoped event ids" do
    test "the id attr prefixes event DOM ids" do
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

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events, tl_id: "fitted"}

      html =
        render(~H"<.timeline id={@tl_id} date={@date} resources={@resources} events={@events} />")

      assert html =~ ~s(id="cal-event-1-fitted-r1")
    end
  end

  describe "bar labels (label_position)" do
    defp narrow_session do
      %Event{
        id: "n1",
        start: ~U[2026-04-01 10:00:00Z],
        end: ~U[2026-04-01 10:03:00Z],
        title: "Chapter twelve",
        resource_id: "r1"
      }
    end

    test ":fit keeps the label inside a wide bar" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 09:00:00Z],
          end: ~U[2026-04-01 12:00:00Z],
          title: "Long morning session",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}
      html = render(~H"<.timeline date={@date} resources={@resources} events={@events} />")

      assert html =~ "cal-event-content"
      assert html =~ "Long morning session"
      refute html =~ "cal-timeline-bar-label"
    end

    test ":fit moves a too-narrow bar's label OUTSIDE the bar" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources, events: [narrow_session()]}

      html = render(~H"<.timeline date={@date} resources={@resources} events={@events} />")

      doc = Floki.parse_document!(html)

      # the bar itself carries no text — tooltip + aria only
      [bar_title] = doc |> Floki.find(~s([id^="cal-event-n1"])) |> Floki.attribute("title")
      assert bar_title == "Chapter twelve"
      assert doc |> Floki.find(~s([id^="cal-event-n1"])) |> Floki.text() |> String.trim() == ""

      # the label renders beside it
      [label] = Floki.find(doc, ".cal-timeline-bar-label")
      assert Floki.text(label) =~ "Chapter twelve"
    end

    test "label_fit_fallback={:none} suppresses instead" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources, events: [narrow_session()]}

      html =
        render(
          ~H"<.timeline date={@date} resources={@resources} events={@events} label_fit_fallback={:none} />"
        )

      refute html =~ "cal-timeline-bar-label"
    end

    test "an outside label at the track edge flips before the bar" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "edge",
          start: ~U[2026-04-01 23:40:00Z],
          end: ~U[2026-04-01 23:45:00Z],
          title: "Nightcap chapter",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}
      html = render(~H"<.timeline date={@date} resources={@resources} events={@events} />")

      doc = Floki.parse_document!(html)
      [style] = doc |> Floki.find(".cal-timeline-bar-label") |> Floki.attribute("style")

      # placed before the ~98% bar, not spilling past 100%
      [_, at] = Regex.run(~r/inset-inline-start: ([\d.]+)%/, style)
      assert String.to_float(at) < 95.0
    end

    test "label_position={:inside} forces the label into a narrow bar" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources, events: [narrow_session()]}

      html =
        render(
          ~H"<.timeline date={@date} resources={@resources} events={@events} label_position={:inside} />"
        )

      assert html =~ "cal-event-content"
      refute html =~ "cal-timeline-bar-label"
    end

    test "label_position={:outside} forces the label beside a wide bar" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 09:00:00Z],
          end: ~U[2026-04-01 12:00:00Z],
          title: "Long morning session",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html =
        render(
          ~H"<.timeline date={@date} resources={@resources} events={@events} label_position={:outside} />"
        )

      refute html =~ "cal-event-content"
      assert html =~ "cal-timeline-bar-label"
    end

    test "an outside label blocked on BOTH sides suppresses itself" do
      # 1-hour window: the bar starts at the track edge (before-gap < 0) and
      # a wide neighbour occupies the rest (after-gap blocked) -> tooltip only.
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "tiny",
          start: ~U[2026-04-01 10:00:00Z],
          end: ~U[2026-04-01 10:03:00Z],
          title: "Chapter twelve",
          resource_id: "r1"
        },
        %Event{
          id: "wide",
          start: ~U[2026-04-01 10:04:00Z],
          end: ~U[2026-04-01 10:57:00Z],
          title: "Big block",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html =
        render(~H"<.timeline
  date={@date}
  resources={@resources}
  events={@events}
  min_time={~T[10:00:00]}
  max_time={~T[11:00:00]}
/>")

      doc = Floki.parse_document!(html)
      labels = doc |> Floki.find(".cal-timeline-bar-label") |> Enum.map(&Floki.text/1)

      refute Enum.any?(labels, &(&1 =~ "Chapter twelve"))
      [tooltip] = doc |> Floki.find(~s([id^="cal-event-tiny"])) |> Floki.attribute("title")
      assert tooltip == "Chapter twelve"
    end

    test "label_position={:none} renders tooltip-only bars" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 09:00:00Z],
          end: ~U[2026-04-01 12:00:00Z],
          title: "Long morning session",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html =
        render(
          ~H"<.timeline date={@date} resources={@resources} events={@events} label_position={:none} />"
        )

      refute html =~ "cal-timeline-bar-label"
      refute html =~ "cal-event-content"
      assert html =~ ~s(title="Long morning session")
    end
  end
end
