defmodule PhoenixLiveCalendar.Views.ResourceViewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Views.ResourceView

  alias PhoenixLiveCalendar.{Event, Resource}

  defp render(content), do: rendered_to_string(content)

  describe "resource_view/1" do
    test "renders resource columns structure" do
      resources = [
        %Resource{id: "r1", title: "Dr. Smith"},
        %Resource{id: "r2", title: "Dr. Jones"}
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources}

      html = render(~H"<.resource_view date={@date} resources={@resources} />")

      assert html =~ "cal-resource-view"
      assert html =~ "cal-resource-headers"
      assert html =~ "cal-resource-body"
    end

    test "renders resource column headers" do
      resources = [
        %Resource{id: "r1", title: "Room A"},
        %Resource{id: "r2", title: "Room B"}
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources}

      html = render(~H"<.resource_view date={@date} resources={@resources} />")

      assert html =~ "Room A"
      assert html =~ "Room B"
      assert html =~ "cal-resource-column-header"
    end

    test "renders correct number of columns" do
      resources = [
        %Resource{id: "r1", title: "A"},
        %Resource{id: "r2", title: "B"},
        %Resource{id: "r3", title: "C"}
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources}

      html = render(~H"<.resource_view date={@date} resources={@resources} />")

      assert html =~ "grid-template-columns: repeat(3, minmax(0, 1fr))"
    end

    test "renders events in correct resource column" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 10:00:00Z],
          end: ~U[2026-04-01 11:00:00Z],
          title: "Appointment",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}

      html = render(~H"<.resource_view date={@date} resources={@resources} events={@events} />")

      assert html =~ "Appointment"
      assert html =~ "top:"
      assert html =~ "height:"
    end

    test "renders time gutter" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources}

      html =
        render(~H"<.resource_view
  date={@date}
  resources={@resources}
  min_time={~T[09:00:00]}
  max_time={~T[12:00:00]}
  slot_duration={60}
/>")

      assert html =~ "cal-time-gutter"
      assert html =~ "09:00"
      assert html =~ "10:00"
      assert html =~ "11:00"
    end

    test "renders resource color indicator" do
      resources = [%Resource{id: "r1", title: "Room A", color: "bg-info"}]
      assigns = %{date: ~D[2026-04-01], resources: resources}

      html = render(~H"<.resource_view date={@date} resources={@resources} />")

      assert html =~ "bg-info"
    end

    test "renders data-resource-id on columns" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      assigns = %{date: ~D[2026-04-01], resources: resources}

      html = render(~H"<.resource_view date={@date} resources={@resources} />")

      assert html =~ ~s(data-resource-id="r1")
    end
  end

  describe "0.3 parity (sweep regressions)" do
    test "off-date events are filtered instead of rendering at raw time-of-day" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "wrong-day",
          start: ~U[2026-04-05 10:00:00Z],
          end: ~U[2026-04-05 11:00:00Z],
          title: "Elsewhere",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}
      html = render(~H"<.resource_view date={@date} resources={@resources} events={@events} />")

      refute html =~ "Elsewhere"
    end

    test "an all-day event no longer crashes and spans the visible window" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "allday",
          start: ~D[2026-04-01],
          end: ~D[2026-04-02],
          title: "Maintenance day",
          all_day: true,
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}
      html = render(~H"<.resource_view date={@date} resources={@resources} events={@events} />")

      assert html =~ "Maintenance day"
      assert html =~ "top: min(0.0%"
    end

    test "a midnight-crossing event clamps to the date instead of a phantom sliver" do
      resources = [%Resource{id: "r1", title: "Room A"}]

      events = [
        %Event{
          id: "night",
          start: ~U[2026-04-01 22:00:00Z],
          end: ~U[2026-04-02 01:00:00Z],
          title: "Night shift",
          resource_id: "r1"
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}
      html = render(~H"<.resource_view date={@date} resources={@resources} events={@events} />")

      # 22:00 of a full-day axis ≈ 91.67%, running to the end — not an
      # inverted-height sliver
      assert html =~ "top: min(91.6"
      assert html =~ "height: max("
    end

    test "resource_ids (plural) renders the event in every matching column" do
      resources = [
        %Resource{id: "r1", title: "Room A"},
        %Resource{id: "r2", title: "Room B"},
        %Resource{id: "r3", title: "Room C"}
      ]

      events = [
        %Event{
          id: "shared",
          start: ~U[2026-04-01 10:00:00Z],
          end: ~U[2026-04-01 11:00:00Z],
          title: "Team booking",
          resource_ids: ["r1", "r3"]
        }
      ]

      assigns = %{date: ~D[2026-04-01], resources: resources, events: events}
      html = render(~H"<.resource_view date={@date} resources={@resources} events={@events} />")

      doc = Floki.parse_document!(html)

      assert length(Floki.find(doc, "[data-resource-id='r1'] .cal-event")) == 1
      assert Floki.find(doc, "[data-resource-id='r2'] .cal-event") == []
      assert length(Floki.find(doc, "[data-resource-id='r3'] .cal-event")) == 1
    end

    test "the now line respects a timezone-correct today and the visible window" do
      resources = [%Resource{id: "r1", title: "Room A"}]
      today = ~D[2026-04-01]
      assigns = %{date: today, today: today, resources: resources}

      shown =
        render(
          ~H"<.resource_view date={@date} today={@today} now={~T[12:00:00]} resources={@resources} />"
        )

      other_day =
        render(
          ~H"<.resource_view date={@date} today={~D[2026-04-02]} now={~T[12:00:00]} resources={@resources} />"
        )

      out_of_window =
        render(~H"<.resource_view
  date={@date}
  today={@today}
  now={~T[05:00:00]}
  min_time={~T[06:00:00]}
  max_time={~T[22:00:00]}
  resources={@resources}
/>")

      assert shown =~ "cal-now-indicator"
      refute other_day =~ "cal-now-indicator"
      refute out_of_window =~ "cal-now-indicator"
    end
  end
end
