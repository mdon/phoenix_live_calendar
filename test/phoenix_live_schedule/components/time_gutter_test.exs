defmodule PhoenixLiveSchedule.Components.TimeGutterTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]
  import PhoenixLiveSchedule.Components.TimeGutter

  defp render(content), do: rendered_to_string(content)

  describe "time_gutter/1" do
    test "renders time labels" do
      slots = [~T[09:00:00], ~T[10:00:00], ~T[11:00:00]]
      assigns = %{slots: slots}

      html = render(~H"<.time_gutter slots={@slots} />")

      assert html =~ "09:00"
      assert html =~ "10:00"
      assert html =~ "11:00"
      assert html =~ "cal-time-gutter"
    end

    test "renders in 12h format" do
      slots = [~T[09:00:00], ~T[14:00:00]]
      assigns = %{slots: slots}

      html = render(~H"<.time_gutter slots={@slots} time_format={:h12} />")

      assert html =~ "9:00 AM"
      assert html =~ "2:00 PM"
    end

    test "renders with custom slot height" do
      slots = [~T[09:00:00]]
      assigns = %{slots: slots}

      html =
        render(~H"""
        <.time_gutter slots={@slots} slot_height="4rem" />
        """)

      assert html =~ "height: 4rem"
    end

    test "renders ARIA role" do
      slots = [~T[09:00:00]]
      assigns = %{slots: slots}

      html = render(~H"<.time_gutter slots={@slots} />")

      assert html =~ ~s(role="rowheader")
      assert html =~ ~s(aria-label="Time")
    end

    test "renders with custom class" do
      slots = [~T[09:00:00]]
      assigns = %{slots: slots}

      html =
        render(~H"""
        <.time_gutter slots={@slots} class="my-gutter" />
        """)

      assert html =~ "my-gutter"
    end
  end

  describe "now_indicator/1" do
    test "renders at correct position" do
      assigns = %{current_time: ~T[12:00:00]}

      html =
        render(~H"<.now_indicator current_time={@current_time} />")

      assert html =~ "cal-now-indicator"
      # Noon should be ~50%
      assert html =~ "top: 50."
      assert html =~ "bg-error"
    end

    test "renders within custom time range" do
      assigns = %{current_time: ~T[12:00:00], min: ~T[08:00:00], max: ~T[20:00:00]}

      html =
        render(~H"<.now_indicator current_time={@current_time} min_time={@min} max_time={@max} />")

      # 12:00 in 8:00-20:00 range = 33.33%
      assert html =~ "top: 33.3"
    end

    test "is aria-hidden" do
      assigns = %{current_time: ~T[12:00:00]}

      html = render(~H"<.now_indicator current_time={@current_time} />")

      assert html =~ ~s(aria-hidden="true")
    end
  end
end
