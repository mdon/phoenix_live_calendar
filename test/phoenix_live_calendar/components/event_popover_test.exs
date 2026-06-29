defmodule PhoenixLiveCalendar.Components.EventPopoverTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Components.EventPopover

  alias PhoenixLiveCalendar.Event

  defp render(content), do: rendered_to_string(content)

  defp event do
    %Event{
      id: "e1",
      title: "Standup",
      start: ~U[2026-04-01 09:00:00Z],
      end: ~U[2026-04-01 09:30:00Z],
      all_day: false,
      editable: true,
      status: :confirmed,
      location: "Room 1",
      description: "Daily sync"
    }
  end

  describe "event_popover/1" do
    test "renders nothing when show is false" do
      assigns = %{event: event()}
      refute render(~H"<.event_popover show={false} event={@event} />") =~ "cal-popover"
    end

    test "renders nothing when the event is nil" do
      assigns = %{}
      refute render(~H"<.event_popover show={true} event={nil} />") =~ "cal-popover"
    end

    test "renders the detail dialog with title, time, location and description" do
      assigns = %{event: event()}
      html = render(~H"<.event_popover show={true} event={@event} />")

      assert html =~ "cal-popover"
      assert html =~ ~s(role="dialog")
      assert html =~ "Standup"
      assert html =~ "Room 1"
      assert html =~ "Daily sync"
      assert html =~ "09:00"
      assert html =~ "09:30"
    end

    test "shows 'All day' for all-day events" do
      assigns = %{
        event: %Event{
          id: "a",
          title: "Holiday",
          start: ~D[2026-04-01],
          end: ~D[2026-04-02],
          all_day: true,
          status: :confirmed
        }
      }

      assert render(~H"<.event_popover show={true} event={@event} />") =~ "All day"
    end

    test "renders a status badge + strikethrough for cancelled events" do
      assigns = %{event: %{event() | status: :cancelled}}
      html = render(~H"<.event_popover show={true} event={@event} />")

      assert html =~ "Cancelled"
      assert html =~ "line-through"
    end

    test "shows Edit/Delete when editable and handlers are given" do
      assigns = %{event: event(), on_edit: "edit", on_delete: "del"}

      html =
        render(
          ~H"<.event_popover show={true} event={@event} on_edit={@on_edit} on_delete={@on_delete} />"
        )

      assert html =~ "Edit"
      assert html =~ "Delete"
    end

    test "hides Edit/Delete for non-editable events" do
      assigns = %{event: %{event() | editable: false}, on_edit: "edit", on_delete: "del"}

      html =
        render(
          ~H"<.event_popover show={true} event={@event} on_edit={@on_edit} on_delete={@on_delete} />"
        )

      refute html =~ "Edit"
      refute html =~ "Delete"
    end

    test "renders a custom inner_block slot instead of the default content" do
      assigns = %{event: event()}

      html =
        render(~H"""
        <.event_popover show={true} event={@event}>
          <span>CUSTOM-{@event.title}</span>
        </.event_popover>
        """)

      assert html =~ "CUSTOM-Standup"
      refute html =~ "Daily sync"
    end
  end
end
