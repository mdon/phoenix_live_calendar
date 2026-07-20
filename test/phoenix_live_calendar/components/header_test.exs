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

  describe "layout" do
    defp base_assigns(views) do
      %{
        title: "July 2026",
        views: views,
        on_prev: "p",
        on_next: "n",
        on_today: "t",
        on_view_change: "v"
      }
    end

    test ":auto collapses to a start-aligned row only when both wings are empty" do
      # single view + today visible + no slots -> empty wings -> start row
      assigns = base_assigns([:month])

      collapsed =
        render(~H|<.header
  title={@title}
  views={@views}
  today_visible={true}
  on_prev={@on_prev}
  on_next={@on_next}
  on_today={@on_today}
  on_view_change={@on_view_change}
/>|)

      assert collapsed =~ "cal-header-start"

      # a visible view switcher keeps the classic centered grid
      assigns = base_assigns([:month, :week])

      centered =
        render(~H|<.header
  title={@title}
  views={@views}
  today_visible={true}
  on_prev={@on_prev}
  on_next={@on_next}
  on_today={@on_today}
  on_view_change={@on_view_change}
/>|)

      refute centered =~ "cal-header-start"
      assert centered =~ "grid-cols-[1fr_auto_1fr]"
      # The base display MUST be unconditional (not a @max-2xl variant):
      # a standalone <.header> without a @container ancestor matches no
      # container query and would fall back to display:block — the three
      # toolbar zones stacking as full-width rows. 0.4.0 review blocker.
      assert centered =~ "flex flex-wrap @2xl:grid"
    end

    test "layout={:start} keeps provided wing content instead of dropping it" do
      assigns = base_assigns([:month, :week])

      html =
        render(~H|<.header
  title={@title}
  layout={:start}
  views={@views}
  today_visible={false}
  on_prev={@on_prev}
  on_next={@on_next}
  on_today={@on_today}
  on_view_change={@on_view_change}
/>|)

      assert html =~ "cal-header-start"
      # today button and view switcher still render, inline
      assert html =~ "cal-nav-today"
      assert html =~ "cal-view-btn"
    end
  end
end
