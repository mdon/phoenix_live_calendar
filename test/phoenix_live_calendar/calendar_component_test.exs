defmodule PhoenixLiveCalendar.CalendarComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import ExUnit.CaptureLog, only: [with_log: 1]

  alias Phoenix.Component
  alias Phoenix.LiveView.Socket
  alias PhoenixLiveCalendar.CalendarComponent

  # Drives the LiveComponent's mount/update callbacks directly — the library
  # ships no test endpoint, so this exercises the :date/:view sync logic without
  # a full LiveView harness.
  defp mounted do
    {:ok, socket} = CalendarComponent.mount(%Socket{})
    socket
  end

  defp update(socket, assigns) do
    {:ok, socket} = CalendarComponent.update(assigns, socket)
    socket
  end

  describe "view/date sync" do
    test "defaults to month/today when no :view or :date is passed" do
      socket = mounted() |> update(%{})
      assert socket.assigns.internal_view == :month
      assert %Date{} = socket.assigns.internal_date
    end

    test "an initial :view / :date prop seeds the internal state" do
      socket = mounted() |> update(%{view: :week, date: ~D[2026-06-01]})
      assert socket.assigns.internal_view == :week
      assert socket.assigns.internal_date == ~D[2026-06-01]
    end

    test "a :today prop (without :date) seeds internal_date" do
      # A timezone-correct today must win over the server's UTC today, or a
      # viewer east of UTC opens the calendar on the wrong month late evening.
      local_today = Date.add(Date.utc_today(), 60)
      socket = mounted() |> update(%{today: local_today})
      assert socket.assigns.internal_date == local_today
    end

    test "an explicit :date wins over :today for the initial anchor" do
      socket = mounted() |> update(%{today: ~D[2026-08-15], date: ~D[2026-06-01]})
      assert socket.assigns.internal_date == ~D[2026-06-01]
    end

    test "a later :today change does not snap the user's navigation" do
      socket = mounted() |> update(%{today: ~D[2026-08-15]})

      # User navigates to another month (lc_navigate owns internal_date).
      socket = Component.assign(socket, :internal_date, ~D[2026-10-01])

      # Midnight rolls today over — must not yank the calendar back.
      socket = update(socket, %{today: ~D[2026-08-16]})
      assert socket.assigns.internal_date == ~D[2026-10-01]
    end

    test "the switcher's flat n_day value rehydrates the day count" do
      # The header serializes {:n_day, n} as "n_day" (a tuple isn't
      # attribute-safe); the handler must rebuild the tuple from n_days or
      # the internal view dispatches to the unknown-view fallback.
      socket = mounted() |> update(%{view: :month, date: ~D[2026-06-01], n_days: 3})

      {:noreply, socket} =
        CalendarComponent.handle_event("lc_view_change", %{"view" => "n_day"}, socket)

      assert socket.assigns.internal_view == {:n_day, 3}
    end

    test "n_day defaults to 4 days when n_days is not set" do
      socket = mounted() |> update(%{view: :month, date: ~D[2026-06-01]})

      {:noreply, socket} =
        CalendarComponent.handle_event("lc_view_change", %{"view" => "n_day"}, socket)

      assert socket.assigns.internal_view == {:n_day, 4}
    end

    test "a re-render passing the SAME :view preserves the user's navigation" do
      socket = mounted() |> update(%{view: :month, date: ~D[2026-06-01]})

      # User navigates (the component owns internal_view via lc_view_change).
      socket = Component.assign(socket, :internal_view, :week)

      # Parent re-renders with the same props (e.g. a PubSub reload) — must NOT
      # snap the view back to :month.
      socket = update(socket, %{view: :month, date: ~D[2026-06-01]})
      assert socket.assigns.internal_view == :week
    end

    test "a re-render passing the SAME :date preserves the user's month navigation" do
      socket = mounted() |> update(%{view: :month, date: ~D[2026-06-01]})

      # User navigates to the next month (lc_navigate updates internal_date).
      socket = Component.assign(socket, :internal_date, ~D[2026-07-01])

      socket = update(socket, %{view: :month, date: ~D[2026-06-01]})
      assert socket.assigns.internal_date == ~D[2026-07-01]
    end

    test "a parent that actually CHANGES :view still drives the component" do
      socket =
        mounted()
        |> update(%{view: :month})
        |> Component.assign(:internal_view, :week)

      # Parent deliberately switches the controlled value.
      socket = update(socket, %{view: :day})
      assert socket.assigns.internal_view == :day
    end

    test "a parent that actually CHANGES :date still drives the component" do
      socket =
        mounted()
        |> update(%{date: ~D[2026-06-01]})
        |> Component.assign(:internal_date, ~D[2026-07-01])

      socket = update(socket, %{date: ~D[2026-09-15]})
      assert socket.assigns.internal_date == ~D[2026-09-15]
    end
  end

  describe "handle_event — navigation" do
    test "lc_navigate :next advances the date for the current view" do
      socket = mounted() |> update(%{view: :month, date: ~D[2026-06-15]})

      {:noreply, s} =
        CalendarComponent.handle_event("lc_navigate", %{"direction" => "next"}, socket)

      assert Date.compare(s.assigns.internal_date, ~D[2026-06-15]) == :gt
      assert s.assigns.internal_date.month == 7
    end

    test "lc_navigate :prev moves the date back" do
      socket = mounted() |> update(%{view: :month, date: ~D[2026-06-15]})

      {:noreply, s} =
        CalendarComponent.handle_event("lc_navigate", %{"direction" => "prev"}, socket)

      assert s.assigns.internal_date.month == 5
    end

    test "lc_navigate with a bad direction defaults to :next (logged)" do
      socket = mounted() |> update(%{view: :month, date: ~D[2026-06-15]})

      {{:noreply, s}, log} =
        with_log(fn ->
          CalendarComponent.handle_event("lc_navigate", %{"direction" => "sideways"}, socket)
        end)

      assert s.assigns.internal_date.month == 7
      assert log =~ "Invalid direction"
    end

    test "lc_today resets to the today assign" do
      socket = mounted() |> update(%{view: :month, date: ~D[2026-01-01], today: ~D[2026-06-29]})
      {:noreply, s} = CalendarComponent.handle_event("lc_today", %{}, socket)

      assert s.assigns.internal_date == ~D[2026-06-29]
    end

    test "lc_view_change switches the view and fires on_view_change" do
      pid = self()

      socket =
        mounted() |> update(%{view: :month, date: ~D[2026-06-01], on_view_change: cb(pid, :vc)})

      {:noreply, s} = CalendarComponent.handle_event("lc_view_change", %{"view" => "week"}, socket)

      assert s.assigns.internal_view == :week
      assert_received {:vc, %{view: :week}}
    end

    test "lc_view_change ignores an invalid view (logged)" do
      socket = mounted() |> update(%{view: :month, date: ~D[2026-06-01]})

      {{:noreply, s}, log} =
        with_log(fn ->
          CalendarComponent.handle_event("lc_view_change", %{"view" => "bogus"}, socket)
        end)

      assert s.assigns.internal_view == :month
      assert log =~ "Invalid view"
    end

    test "navigation fires on_date_range_change with the visible range" do
      pid = self()

      socket =
        mounted()
        |> update(%{view: :month, date: ~D[2026-06-15], on_date_range_change: cb(pid, :dr)})

      CalendarComponent.handle_event("lc_navigate", %{"direction" => "next"}, socket)

      assert_received {:dr, %{view: :month, start: %Date{}, end: %Date{}}}
    end
  end

  describe "handle_event — callbacks" do
    test "lc_date_click fires on_date_select with the parsed date" do
      pid = self()
      socket = mounted() |> update(%{on_date_select: cb(pid, :ds)})
      CalendarComponent.handle_event("lc_date_click", %{"date" => "2026-06-15"}, socket)

      assert_received {:ds, ~D[2026-06-15]}
    end

    test "lc_date_click ignores a malformed date (logged, no callback)" do
      pid = self()
      socket = mounted() |> update(%{on_date_select: cb(pid, :ds)})

      {_, log} =
        with_log(fn ->
          CalendarComponent.handle_event("lc_date_click", %{"date" => "nope"}, socket)
        end)

      refute_received {:ds, _}
      assert log =~ "Invalid date"
    end

    test "lc_time_click fires on_time_select with date/time/datetime" do
      pid = self()
      socket = mounted() |> update(%{on_time_select: cb(pid, :ts)})

      CalendarComponent.handle_event(
        "lc_time_click",
        %{"date" => "2026-06-15", "time" => "09:30:00", "resource-id" => "r1"},
        socket
      )

      assert_received {:ts,
                       %{
                         date: ~D[2026-06-15],
                         time: ~T[09:30:00],
                         datetime: ~N[2026-06-15 09:30:00],
                         resource_id: "r1"
                       }}
    end

    test "lc_event_click fires on_event_click with the id" do
      pid = self()
      socket = mounted() |> update(%{on_event_click: cb(pid, :ec)})
      CalendarComponent.handle_event("lc_event_click", %{"event-id" => "e42"}, socket)

      assert_received {:ec, "e42"}
    end

    test "lc_more_click fires on_more_click with the date" do
      pid = self()
      socket = mounted() |> update(%{on_more_click: cb(pid, :mc)})
      CalendarComponent.handle_event("lc_more_click", %{"date" => "2026-06-15"}, socket)

      assert_received {:mc, ~D[2026-06-15]}
    end

    test "lc_range_select fires on_range_select" do
      pid = self()
      socket = mounted() |> update(%{on_range_select: cb(pid, :rs)})

      CalendarComponent.handle_event(
        "lc_range_select",
        %{"date" => "2026-06-15", "start_time" => "09:00:00", "end_time" => "10:00:00"},
        socket
      )

      assert_received {:rs,
                       %{date: ~D[2026-06-15], start_time: ~T[09:00:00], end_time: ~T[10:00:00]}}
    end

    test "lc_event_drop fires on_event_drop with parsed fields" do
      pid = self()
      socket = mounted() |> update(%{on_event_drop: cb(pid, :ed)})

      CalendarComponent.handle_event(
        "lc_event_drop",
        %{
          "event_id" => "e",
          "new_date" => "2026-06-20",
          "new_time" => "11:00:00",
          "resource_id" => "r"
        },
        socket
      )

      assert_received {:ed,
                       %{
                         event_id: "e",
                         new_date: ~D[2026-06-20],
                         new_time: ~T[11:00:00],
                         resource_id: "r"
                       }}
    end

    test "lc_event_resize fires on_event_resize" do
      pid = self()
      socket = mounted() |> update(%{on_event_resize: cb(pid, :er)})

      CalendarComponent.handle_event(
        "lc_event_resize",
        %{"event_id" => "e", "edge" => "bottom", "new_time" => "12:30:00"},
        socket
      )

      assert_received {:er, %{event_id: "e", edge: "bottom", new_time: ~T[12:30:00]}}
    end

    test "lc_container_resized fires on_container_resized with a rounded width" do
      pid = self()
      socket = mounted() |> update(%{on_container_resized: cb(pid, :cr)})
      CalendarComponent.handle_event("lc_container_resized", %{"width" => 812.7}, socket)

      assert_received {:cr, %{width: 813}}
    end

    test "an unknown event is ignored (logged, socket unchanged)" do
      socket = mounted() |> update(%{view: :month, date: ~D[2026-06-01]})

      {{:noreply, s}, log} =
        with_log(fn -> CalendarComponent.handle_event("bogus_event", %{}, socket) end)

      assert s.assigns.internal_view == :month
      assert log =~ "Unhandled event"
    end

    test "a raising callback is caught — the handler still returns :noreply" do
      socket = mounted() |> update(%{on_date_select: fn _ -> raise "boom" end})

      {result, log} =
        with_log(fn ->
          CalendarComponent.handle_event("lc_date_click", %{"date" => "2026-06-15"}, socket)
        end)

      assert {:noreply, _} = result
      assert log =~ "raised"
    end

    test "a callback assigned as a non-function is ignored (logged)" do
      socket = mounted() |> update(%{on_date_select: :not_a_fun})

      {{:noreply, _}, log} =
        with_log(fn ->
          CalendarComponent.handle_event("lc_date_click", %{"date" => "2026-06-15"}, socket)
        end)

      assert log =~ "Expected function"
    end
  end

  describe "render/1" do
    test "renders each view's own content (not the unknown-view fallback)" do
      # day / n_day delegate to WeekGrid, so they carry cal-week-* classes.
      views = [
        {:month, "cal-month"},
        {:week, "cal-week"},
        {:day, "cal-week"},
        {{:n_day, 3}, "cal-week"},
        {:year, "cal-year"},
        {:agenda, "cal-agenda"},
        {:timeline, "cal-timeline"},
        {:resource, "cal-resource"}
      ]

      for {view, expected_class} <- views do
        html = render_html(view)
        assert html =~ "cal-container"

        assert html =~ expected_class,
               "expected #{inspect(view)} to render a #{expected_class} element"

        refute html =~ "Unknown view", "#{inspect(view)} fell through to the unknown-view fallback"
      end
    end

    test "shows the header by default and hides it on show_header: false" do
      assert render_html(:month) =~ "cal-header"
      refute render_html(:month, %{show_header: false}) =~ "cal-header"
    end

    test "forwards fixed_weeks to the month grid (6 rows default, fewer when false)" do
      week_rows = fn html -> html |> String.split("cal-week-row") |> length() |> Kernel.-(1) end

      # render_html anchors on 2026-06-15 — June 2026 spans 5 natural weeks.
      assert week_rows.(render_html(:month)) == 6
      assert week_rows.(render_html(:month, %{fixed_weeks: false})) == 5
    end

    test "forwards marker_ticker: false to the month grid" do
      # Was read via assigns[:marker_ticker] inside the dispatcher but never
      # declared/passed through render_view — a consumer's false was ignored.
      markers = [
        %PhoenixLiveCalendar.DayMarker{id: "m1", label: "Alpha", start_date: ~D[2026-06-10]},
        %PhoenixLiveCalendar.DayMarker{id: "m2", label: "Beta", start_date: ~D[2026-06-10]}
      ]

      assert render_html(:month, %{day_markers: markers}) =~ "cal-marker-ticker"

      refute render_html(:month, %{day_markers: markers, marker_ticker: false}) =~
               "cal-marker-ticker"
    end

    test "prefixes month ticker ids with the component id" do
      markers = [
        %PhoenixLiveCalendar.DayMarker{id: "m1", label: "Alpha", start_date: ~D[2026-06-10]},
        %PhoenixLiveCalendar.DayMarker{id: "m2", label: "Beta", start_date: ~D[2026-06-10]}
      ]

      # Two components on one page get distinct ticker ids via their own id.
      assert render_html(:month, %{day_markers: markers}) =~ ~s(id="cal-month-ticker-2026-06-10)
    end

    test "forwards slot_width and resource_width to the timeline" do
      # Previously unreachable from the wrapper entirely.
      html =
        render_html(:timeline, %{
          resources: [%PhoenixLiveCalendar.Resource{id: "r1", title: "Room A"}],
          slot_width: "8rem",
          resource_width: "16rem"
        })

      assert html =~ "width: 8rem"
      assert html =~ "width: 16rem"
    end

    test "renders a switcher button for an {:n_day, n} view without crashing" do
      # A tuple isn't attribute-safe — the header must serialize it flat.
      html = render_html(:month, %{views: [:month, {:n_day, 3}]})

      assert html =~ ~s(phx-value-view="n_day")
      assert html =~ "3 Day"
    end
  end

  describe "events_mode windowing" do
    test ":window keeps events straddling the visible range boundary" do
      # Spills into the June grid from May — trimming it would visibly drop
      # the bar segments in the first June cells.
      event = %PhoenixLiveCalendar.Event{
        id: "straddle",
        start: ~D[2026-05-30],
        end: ~D[2026-06-03],
        title: "Straddler",
        all_day: true
      }

      html = render_html(:month, %{events: [event], events_mode: :window})

      assert html =~ "Straddler"
    end

    test ":window renders in-range events identically to :full" do
      event = %PhoenixLiveCalendar.Event{
        id: "1",
        start: ~D[2026-06-10],
        title: "In range",
        all_day: true
      }

      far_event = %PhoenixLiveCalendar.Event{
        id: "2",
        start: ~D[2026-12-24],
        title: "Far away",
        all_day: true
      }

      windowed = render_html(:month, %{events: [event, far_event], events_mode: :window})
      full = render_html(:month, %{events: [event, far_event]})

      assert windowed =~ "In range"
      assert windowed == full
    end
  end

  describe "slot forwarding" do
    # The views always had :event/:day_cell/... slots, but the documented
    # entrypoint declared none and never forwarded them — wrapper users
    # could not customize event rendering at all.
    test "the :event slot reaches the month grid" do
      event = %PhoenixLiveCalendar.Event{
        id: "1",
        start: ~D[2026-06-10],
        title: "Holiday",
        all_day: true
      }

      html = render_html(:month, %{events: [event], event: [event_slot()]})

      assert html =~ "custom-event-slot"
      assert html =~ "Holiday!!"
    end

    test "the :event slot reaches the week grid and the timeline" do
      event = %PhoenixLiveCalendar.Event{
        id: "1",
        start: ~U[2026-06-15 10:00:00Z],
        end: ~U[2026-06-15 11:00:00Z],
        title: "Meeting",
        resource_id: "r1"
      }

      week_html = render_html(:week, %{events: [event], event: [event_slot()]})
      assert week_html =~ "Meeting!!"

      timeline_html =
        render_html(:timeline, %{
          events: [event],
          resources: [%PhoenixLiveCalendar.Resource{id: "r1", title: "Room A"}],
          event: [event_slot()]
        })

      assert timeline_html =~ "Meeting!!"
    end

    test "the :day_cell slot replaces month cells" do
      day_cell = %{
        __slot__: :day_cell,
        inner_block: fn _index, %{date: date} ->
          assigns = %{date: date}
          ~H|<span class="custom-day-cell">{@date.day}</span>|
        end
      }

      html = render_html(:month, %{day_cell: [day_cell]})

      assert html =~ "custom-day-cell"
    end

    test "no slots passed renders the default markup unchanged" do
      event = %PhoenixLiveCalendar.Event{
        id: "1",
        start: ~D[2026-06-10],
        title: "Holiday",
        all_day: true
      }

      html = render_html(:month, %{events: [event]})

      assert html =~ "Holiday"
      refute html =~ "custom-event-slot"
    end
  end

  # -- helpers --

  defp cb(pid, tag), do: fn data -> send(pid, {tag, data}) end

  # A hand-built slot entry (what the ~H engine produces for <:event :let={e}>).
  defp event_slot do
    %{
      __slot__: :event,
      inner_block: fn _index, event ->
        assigns = %{event: event}
        ~H|<span class="custom-event-slot">{@event.title}!!</span>|
      end
    }
  end

  defp render_html(view, extra \\ %{}) do
    base = %{
      id: "cal",
      events: [],
      resources: [],
      today: ~D[2026-06-15],
      view: view,
      date: ~D[2026-06-15]
    }

    socket = mounted() |> update(Map.merge(base, extra))

    # :myself is a reserved assign that `assign/2` refuses, so set it directly on
    # the assigns map (render/1 only reads @myself for JS push targets).
    socket.assigns
    |> Map.put(:myself, %Phoenix.LiveComponent.CID{cid: 1})
    |> CalendarComponent.render()
    |> rendered_to_string()
  end
end
