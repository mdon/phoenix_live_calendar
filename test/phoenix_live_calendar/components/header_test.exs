defmodule PhoenixLiveCalendar.Components.HeaderTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveCalendar.Components.Header

  defp render(content), do: rendered_to_string(content)

  describe "header/1" do
    test "renders title" do
      assigns = %{title: "April 2026", on_prev: "prev", on_next: "next", on_today: "today"}

      html =
        render(~H"""
        <.header title={@title} on_prev={@on_prev} on_next={@on_next} on_today={@on_today} />
        """)

      assert html =~ "April 2026"
      assert html =~ "cal-title"
      assert html =~ ~s(aria-live="polite")
    end

    test "renders navigation buttons" do
      assigns = %{on_prev: "prev", on_next: "next", on_today: "today"}

      html =
        render(~H"""
        <.header title="Test" on_prev={@on_prev} on_next={@on_next} on_today={@on_today} />
        """)

      assert html =~ "cal-nav-prev"
      assert html =~ "cal-nav-next"
      assert html =~ "cal-nav-today"
      assert html =~ "Today"
    end

    test "renders view switcher with multiple views" do
      assigns = %{
        on_prev: "prev",
        on_next: "next",
        on_today: "today",
        on_view_change: "change"
      }

      html =
        render(~H"""
        <.header
          title="Test"
          view={:month}
          views={[:month, :week, :day]}
          on_prev={@on_prev}
          on_next={@on_next}
          on_today={@on_today}
          on_view_change={@on_view_change}
        />
        """)

      assert html =~ "Month"
      assert html =~ "Week"
      assert html =~ "Day"
      assert html =~ "cal-view-btn"
      assert html =~ ~s(aria-pressed="true")
    end

    test "hides view switcher with single view" do
      assigns = %{on_prev: "prev", on_next: "next", on_today: "today", on_view_change: "change"}

      html =
        render(~H"""
        <.header
          title="Test"
          views={[:month]}
          on_prev={@on_prev}
          on_next={@on_next}
          on_today={@on_today}
          on_view_change={@on_view_change}
        />
        """)

      refute html =~ "cal-view-btn"
    end

    test "renders with custom translations" do
      assigns = %{
        on_prev: "prev",
        on_next: "next",
        on_today: "today",
        translations: %{labels: %{today: "Aujourd'hui"}}
      }

      html =
        render(~H"""
        <.header
          title="Avril 2026"
          on_prev={@on_prev}
          on_next={@on_next}
          on_today={@on_today}
          translations={@translations}
        />
        """)

      assert html =~ "Aujourd&#39;hui"
    end

    test "renders RTL direction" do
      assigns = %{on_prev: "prev", on_next: "next", on_today: "today"}

      html =
        render(~H"""
        <.header title="Test" dir={:rtl} on_prev={@on_prev} on_next={@on_next} on_today={@on_today} />
        """)

      assert html =~ "cal-icon-next"
    end

    test "renders toolbar role" do
      assigns = %{on_prev: "prev", on_next: "next", on_today: "today"}

      html =
        render(~H"""
        <.header title="Test" on_prev={@on_prev} on_next={@on_next} on_today={@on_today} />
        """)

      assert html =~ ~s(role="toolbar")
    end
  end
end
