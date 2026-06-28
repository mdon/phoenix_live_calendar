defmodule PhoenixLiveSchedule.Views.AgendaTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveSchedule.Views.Agenda

  alias PhoenixLiveSchedule.Event

  defp render(content), do: rendered_to_string(content)

  describe "agenda/1" do
    test "renders agenda structure" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.agenda date={@date} />")

      assert html =~ "cal-agenda"
      assert html =~ ~s(role="list")
    end

    test "renders empty state when no events" do
      assigns = %{date: ~D[2026-04-01]}

      html = render(~H"<.agenda date={@date} events={[]} />")

      assert html =~ "No events"
      assert html =~ "cal-agenda-empty"
    end

    test "renders events grouped by date" do
      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 10:00:00Z],
          end: ~U[2026-04-01 11:00:00Z],
          title: "Morning"
        },
        %Event{
          id: "2",
          start: ~U[2026-04-02 14:00:00Z],
          end: ~U[2026-04-02 15:00:00Z],
          title: "Afternoon"
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}

      html = render(~H"<.agenda date={@date} events={@events} days={7} />")

      assert html =~ "Morning"
      assert html =~ "Afternoon"
      assert html =~ "cal-agenda-day"
    end

    test "renders date headers" do
      events = [
        %Event{id: "1", start: ~U[2026-04-01 10:00:00Z], title: "Test"}
      ]

      assigns = %{date: ~D[2026-04-01], events: events}

      html = render(~H"<.agenda date={@date} events={@events} />")

      assert html =~ "cal-agenda-day-header"
      assert html =~ "Wed, Apr 1"
    end

    test "renders all-day events with label" do
      events = [
        %Event{id: "1", start: ~D[2026-04-01], title: "Holiday", all_day: true}
      ]

      assigns = %{date: ~D[2026-04-01], events: events}

      html = render(~H"<.agenda date={@date} events={@events} />")

      assert html =~ "Holiday"
      assert html =~ "All day"
    end

    test "renders event time range" do
      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 10:00:00Z],
          end: ~U[2026-04-01 11:30:00Z],
          title: "Meeting"
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}

      html = render(~H"<.agenda date={@date} events={@events} />")

      assert html =~ "10:00"
      assert html =~ "11:30"
    end

    test "renders event location" do
      events = [
        %Event{id: "1", start: ~U[2026-04-01 10:00:00Z], title: "Meeting", location: "Room 101"}
      ]

      assigns = %{date: ~D[2026-04-01], events: events}

      html = render(~H"<.agenda date={@date} events={@events} />")

      assert html =~ "Room 101"
    end

    test "shows empty days when enabled" do
      assigns = %{date: ~D[2026-04-01], events: []}

      html = render(~H"<.agenda date={@date} events={[]} show_empty_days={true} days={3} />")

      assert html =~ "cal-agenda-day-header"
      assert html =~ "No events"
    end

    test "renders today badge" do
      today = Date.utc_today()
      events = [%Event{id: "1", start: today, title: "Today Event", all_day: true}]
      assigns = %{date: today, events: events, today: today}

      html = render(~H"<.agenda date={@date} events={@events} today={@today} />")

      assert html =~ "Today"
      assert html =~ "badge"
    end

    test "renders event color dot" do
      events = [
        %Event{id: "1", start: ~U[2026-04-01 10:00:00Z], title: "Test", color: "bg-success"}
      ]

      assigns = %{date: ~D[2026-04-01], events: events}

      html = render(~H"<.agenda date={@date} events={@events} />")

      assert html =~ "bg-success"
      assert html =~ "rounded-full"
    end

    test "renders in 12h time format" do
      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-01 14:30:00Z],
          end: ~U[2026-04-01 15:00:00Z],
          title: "PM Meeting"
        }
      ]

      assigns = %{date: ~D[2026-04-01], events: events}

      html = render(~H"<.agenda date={@date} events={@events} time_format={:h12} />")

      assert html =~ "2:30 PM"
    end
  end
end
