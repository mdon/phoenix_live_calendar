defmodule LiveCalendar.Components.EventItemTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import LiveCalendar.Components.EventItem

  alias LiveCalendar.Event

  defp render(content), do: rendered_to_string(content)

  describe "event_item/1" do
    test "renders event with title" do
      event = %Event{id: "1", start: ~U[2026-04-01 10:00:00Z], title: "Team Meeting"}
      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} />")

      assert html =~ "Team Meeting"
      assert html =~ "cal-event"
      assert html =~ ~s(data-event-id="1")
    end

    test "renders no-title fallback" do
      event = %Event{id: "1", start: ~U[2026-04-01 10:00:00Z]}
      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} />")

      assert html =~ "(No title)"
    end

    test "renders time in 24h format by default" do
      event = %Event{id: "1", start: ~U[2026-04-01 14:30:00Z], title: "Test"}
      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} />")

      assert html =~ "14:30"
    end

    test "renders time in 12h format" do
      event = %Event{id: "1", start: ~U[2026-04-01 14:30:00Z], title: "Test"}
      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} time_format={:h12} />")

      assert html =~ "2:30 PM"
    end

    test "hides time for all-day events" do
      event = %Event{id: "1", start: ~D[2026-04-01], title: "Holiday", all_day: true}
      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} />")

      assert html =~ "Holiday"
      assert html =~ "cal-event-allday"
      refute html =~ "cal-event-time"
    end

    test "hides time in compact mode" do
      event = %Event{id: "1", start: ~U[2026-04-01 10:00:00Z], title: "Test"}
      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} compact={true} />")

      assert html =~ "Test"
      # The time span with class "cal-event-time" should not be present
      refute html =~ ~s(class="cal-event-time)
    end

    test "renders with custom color class" do
      event = %Event{id: "1", start: ~U[2026-04-01 10:00:00Z], title: "Test", color: "bg-success"}
      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} />")

      assert html =~ "bg-success"
    end

    test "renders data attributes" do
      event = %Event{
        id: "e1",
        start: ~U[2026-04-01 10:00:00Z],
        title: "Test",
        status: :tentative
      }

      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} />")

      assert html =~ ~s(data-event-id="e1")
      assert html =~ ~s(data-editable="true")
      assert html =~ ~s(data-status="tentative")
      assert html =~ ~s(data-all-day="false")
    end

    test "renders aria-label with time range" do
      event = %Event{
        id: "1",
        start: ~U[2026-04-01 10:00:00Z],
        end: ~U[2026-04-01 11:00:00Z],
        title: "Meeting"
      }

      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} />")

      assert html =~ ~s(aria-label="Meeting, 10:00 to 11:00")
    end

    test "renders aria-label for all-day events" do
      event = %Event{id: "1", start: ~D[2026-04-01], title: "Holiday", all_day: true}
      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} />")

      assert html =~ ~s(aria-label="Holiday, all day")
    end

    test "renders background event class" do
      event = %Event{
        id: "1",
        start: ~U[2026-04-01 10:00:00Z],
        title: "BG",
        display: :background
      }

      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} />")

      assert html =~ "cal-event-bg"
    end

    test "renders with custom class" do
      event = %Event{id: "1", start: ~U[2026-04-01 10:00:00Z], title: "Test"}
      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} class=\"my-custom\" />")

      assert html =~ "my-custom"
    end

    test "renders cursor-pointer when clickable" do
      event = %Event{id: "1", start: ~U[2026-04-01 10:00:00Z], title: "Test"}
      assigns = %{event: event}

      html = render(~H"<.event_item event={@event} on_click=\"click_event\" />")

      assert html =~ "cursor-pointer"
    end

    test "renders with custom inner_block slot" do
      event = %Event{id: "1", start: ~U[2026-04-01 10:00:00Z], title: "Test"}
      assigns = %{event: event}

      html =
        render(~H"""
        <.event_item event={@event}>
          <span class="custom-content">Custom: {@event.title}</span>
        </.event_item>
        """)

      assert html =~ "custom-content"
      assert html =~ "Custom: Test"
      refute html =~ "cal-event-content"
    end
  end
end
