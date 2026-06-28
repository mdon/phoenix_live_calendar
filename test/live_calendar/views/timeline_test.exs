defmodule LiveCalendar.Views.TimelineTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import LiveCalendar.Views.Timeline

  alias LiveCalendar.{Event, Resource}

  defp render(content), do: rendered_to_string(content)

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
      assert html =~ "left:"
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
end
