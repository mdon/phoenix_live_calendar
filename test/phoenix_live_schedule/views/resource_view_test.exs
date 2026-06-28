defmodule PhoenixLiveSchedule.Views.ResourceViewTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveSchedule.Views.ResourceView

  alias PhoenixLiveSchedule.{Event, Resource}

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

      assert html =~ "grid-template-columns: repeat(3, 1fr)"
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
end
