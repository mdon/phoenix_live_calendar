defmodule PhoenixLiveCalendar.WidgetsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Widgets

  alias PhoenixLiveCalendar.{Event, Resource}

  defp render(content), do: rendered_to_string(content)

  describe "next_events/1" do
    defp pool(now) do
      today = DateTime.to_date(now)

      [
        %Event{
          id: "past",
          start: DateTime.add(now, -3, :hour),
          end: DateTime.add(now, -2, :hour),
          title: "Already over"
        },
        %Event{
          id: "soon",
          start: DateTime.add(now, 2, :hour),
          end: DateTime.add(now, 3, :hour),
          title: "Soon",
          color: :accent
        },
        %Event{
          id: "this-week",
          start: Date.add(today, 3),
          title: "Trip",
          all_day: true
        },
        %Event{
          id: "next-week",
          start: DateTime.add(now, 10 * 24, :hour),
          title: "Review"
        },
        %Event{
          id: "far",
          start: DateTime.add(now, 40 * 24, :hour),
          title: "Beyond horizon"
        }
      ]
    end

    test "lists the next events soonest first, dropping ended and out-of-horizon ones" do
      now = ~U[2026-04-01 12:00:00Z]
      assigns = %{events: pool(now), now: now}

      html = render(~H"<.next_events events={@events} now={@now} limit={5} />")

      assert html =~ "Soon"
      assert html =~ "Trip"
      assert html =~ "Review"
      refute html =~ "Already over"
      refute html =~ "Beyond horizon"

      # soonest first
      assert :binary.match(html, "Soon") |> elem(0) < :binary.match(html, "Trip") |> elem(0)
    end

    test "limit caps the list; when-labels grade time/weekday/date" do
      now = ~U[2026-04-01 12:00:00Z]
      assigns = %{events: pool(now), now: now}

      html = render(~H"<.next_events events={@events} now={@now} limit={2} />")

      refute html =~ "Review"
      # today's event -> a time; this week's -> a weekday name
      assert html =~ "14:00"
      assert html =~ "Sat"
    end

    test "empty pool renders the no-events state, token colors resolve to dots" do
      now = ~U[2026-04-01 12:00:00Z]
      assigns = %{events: [], now: now, pool: pool(now)}

      assert render(~H"<.next_events events={@events} now={@now} />") =~ "No events"
      assert render(~H"<.next_events events={@pool} now={@now} />") =~ "bg-accent"
    end
  end

  describe "next_events ongoing labeling" do
    test "an ongoing multi-day event says Ongoing instead of its past weekday" do
      now = ~U[2026-04-08 12:00:00Z]

      events = [
        %Event{
          id: "trip",
          start: ~D[2026-04-06],
          end: ~D[2026-04-11],
          title: "Conference trip",
          all_day: true
        }
      ]

      assigns = %{events: events, now: now}
      html = render(~H"<.next_events events={@events} now={@now} />")

      assert html =~ "Conference trip"
      assert html =~ "Ongoing"
      refute html =~ ">Mon<"
    end
  end

  describe "next_events interactivity" do
    test "rows are inert by default and clickable with a handler" do
      now = ~U[2026-04-01 12:00:00Z]

      events = [
        %Event{id: "e1", start: DateTime.add(now, 2, :hour), title: "Soon"}
      ]

      assigns = %{events: events, now: now}

      inert = render(~H"<.next_events events={@events} now={@now} />")
      doc = Floki.parse_document!(inert)
      assert Floki.find(doc, "button[disabled]") != []
      assert Floki.find(doc, "button[phx-click]") == []

      wired = render(~H|<.next_events events={@events} now={@now} on_event_click="pick" />|)
      doc = Floki.parse_document!(wired)
      [btn] = Floki.find(doc, "button[phx-click]")
      assert Floki.attribute([btn], "phx-value-event-id") == ["e1"]
    end
  end

  describe "week_strip/1" do
    test "renders seven day cells with dots and a today pill" do
      today = ~D[2026-04-01]

      events = [
        %Event{id: "1", start: ~D[2026-04-01], title: "A", all_day: true, color: :info},
        %Event{id: "2", start: ~U[2026-04-03 10:00:00Z], title: "B"}
      ]

      assigns = %{today: today, events: events}

      html = render(~H"<.week_strip date={@today} today={@today} events={@events} />")

      doc = Floki.parse_document!(html)
      assert length(Floki.find(doc, ".cal-week-strip-day")) == 7
      assert html =~ "bg-primary text-primary-content"
      assert html =~ "bg-info"
    end

    test "more than three events collapses to a +N count" do
      today = ~D[2026-04-01]

      events =
        for i <- 1..5 do
          %Event{id: "#{i}", start: ~D[2026-04-01], title: "E#{i}", all_day: true}
        end

      assigns = %{today: today, events: events}
      html = render(~H"<.week_strip date={@today} today={@today} events={@events} />")

      assert html =~ "+5"
    end
  end

  describe "activity_grid/1" do
    test "renders weeks x 7 intensity squares with tooltips" do
      to = ~D[2026-04-05]

      data = %{
        ~D[2026-04-01] => 10,
        ~D[2026-03-15] => 100
      }

      assigns = %{data: data, to: to}

      html = render(~H"<.activity_grid data={@data} to={@to} weeks={4} />")

      doc = Floki.parse_document!(html)
      cells = Floki.find(doc, ".cal-activity-cell")
      assert length(cells) == 28

      assert html =~ "bg-success"
      assert html =~ "2026-04-01 — 10"
      # inactive days get the neutral base cell
      assert html =~ "bg-base-content/8"
    end

    test "palette presets apply" do
      assigns = %{data: %{~D[2026-04-01] => 5}, to: ~D[2026-04-05]}

      html = render(~H"<.activity_grid data={@data} to={@to} weeks={2} palette={:heat} />")

      assert html =~ "bg-error"
    end
  end

  describe "activity_grid boundary" do
    test "days after `to` stay blank even when the week runs past it" do
      # `to` mid-week: the strip aligns to the week end but future days
      # must not render as (empty) activity cells.
      to = ~D[2026-04-01]
      assigns = %{data: %{~D[2026-04-01] => 5}, to: to}

      html = render(~H"<.activity_grid data={@data} to={@to} weeks={2} />")

      doc = Floki.parse_document!(html)

      future =
        doc
        |> Floki.find(".cal-activity-cell")
        |> Enum.filter(fn el ->
          [title] = Floki.attribute([el], "title")
          String.slice(title, 0, 10) > "2026-04-01"
        end)

      assert future != []

      Enum.each(future, fn el ->
        [class] = Floki.attribute([el], "class")
        assert class =~ "invisible"
      end)
    end
  end

  describe "activity_month/1" do
    test "renders one month of squares in calendar orientation" do
      data = %{~D[2026-04-10] => 30, ~D[2026-04-11] => 90}
      assigns = %{data: data, date: ~D[2026-04-15], today: ~D[2026-04-16]}

      html =
        render(~H"<.activity_month data={@data} date={@date} today={@today} max={100} />")

      doc = Floki.parse_document!(html)
      cells = Floki.find(doc, ".cal-activity-cell")

      # April 2026 with Monday start spans 5 grid weeks
      assert length(cells) == 35
      assert html =~ "bg-success/40"
      assert html =~ "2026-04-10 — 30"
      # today ringed; out-of-month placeholders invisible but keep alignment
      assert html =~ "ring-primary"
      assert html =~ "invisible"
      # weekday initials header
      assert html =~ "cal-activity-day-initial"
    end

    test "show_day_initials={false} drops the header row" do
      assigns = %{data: %{~D[2026-04-10] => 5}, date: ~D[2026-04-15]}

      html =
        render(~H"<.activity_month data={@data} date={@date} show_day_initials={false} />")

      refute html =~ "cal-activity-day-initial"
    end
  end

  describe "today: :none" do
    test "week_strip and activity_month render without today decorations" do
      today = Date.utc_today()
      assigns = %{data: %{today => 5}, today: today}

      strip = render(~H"<.week_strip date={@today} today={:none} />")
      refute strip =~ "bg-primary text-primary-content"

      month = render(~H"<.activity_month data={@data} date={@today} today={:none} />")
      refute month =~ "ring-primary"
    end
  end

  describe "week_start variants" do
    test "activity_month orders day initials from the configured week start" do
      assigns = %{data: %{~D[2026-04-10] => 5}, date: ~D[2026-04-15]}

      sunday_first =
        render(~H"<.activity_month data={@data} date={@date} week_start={7} />")

      doc = Floki.parse_document!(sunday_first)

      initials =
        doc
        |> Floki.find(".cal-activity-day-initial")
        |> Enum.map(&(&1 |> Floki.text() |> String.trim()))

      assert initials == ["S", "M", "T", "W", "T", "F", "S"]
    end

    test "week_strip anchors its week to the configured start" do
      # 2026-04-15 is a Wednesday; a Sunday-start week begins Apr 12
      assigns = %{date: ~D[2026-04-15]}

      html = render(~H"<.week_strip date={@date} week_start={7} />")

      doc = Floki.parse_document!(html)
      [first_btn | _] = Floki.find(doc, ".cal-week-strip-day")
      assert Floki.attribute([first_btn], "phx-value-date") == ["2026-04-12"]
    end
  end

  describe "mini_timeline/1" do
    test "renders a compressed fitted timeline without axis or labels" do
      resources = [
        %Resource{id: "r1", title: "One Piece"},
        %Resource{id: "r2", title: "Berserk"},
        %Resource{id: "r3", title: "Frieren"},
        %Resource{id: "r4", title: "Overflow"}
      ]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 09:00:00Z],
          end: ~U[2026-04-01 10:30:00Z],
          title: "Morning read",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html = render(~H"<.mini_timeline date={@date} resources={@resources} events={@events} />")

      assert html =~ "cal-mini-timeline"
      refute html =~ "cal-timeline-time-header"
      refute html =~ "cal-event-content"
      assert html =~ ~s(title="Morning read")
      # max_rows caps the resources
      refute html =~ "Overflow"
    end

    test "resource labels clip inside their column instead of running under bars" do
      resources = [%Resource{id: "r1", title: "A very long series name indeed"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 09:00:00Z],
          end: ~U[2026-04-01 10:00:00Z],
          title: "Read",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html = render(~H"<.mini_timeline date={@date} resources={@resources} events={@events} />")

      doc = Floki.parse_document!(html)
      [cell_class] = doc |> Floki.find(".cal-timeline-resource-label") |> Floki.attribute("class")

      assert cell_class =~ "overflow-hidden"
      assert cell_class =~ "min-w-0"
    end
  end
end
