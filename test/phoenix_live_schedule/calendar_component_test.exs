defmodule PhoenixLiveSchedule.CalendarComponentTest do
  use ExUnit.Case, async: true

  alias Phoenix.Component
  alias Phoenix.LiveView.Socket
  alias PhoenixLiveSchedule.CalendarComponent

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
end
