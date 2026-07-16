defmodule PhoenixLiveCalendar.ThemeTest do
  # async: false — some tests set the :color_tokens app env.
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  import Phoenix.Component, only: [sigil_H: 2]

  alias PhoenixLiveCalendar.{Event, Theme}

  defp with_tokens(tokens, fun) do
    Application.put_env(:phoenix_live_calendar, :color_tokens, tokens)
    fun.()
  after
    Application.delete_env(:phoenix_live_calendar, :color_tokens)
  end

  describe "resolve/1" do
    test "semantic atoms resolve to their bg/text pair" do
      assert Theme.resolve(:primary) == {"bg-primary", "text-primary-content"}
      assert Theme.resolve(:error) == {"bg-error", "text-error-content"}
    end

    test "raw class strings pass through with no text pair" do
      assert Theme.resolve("bg-fuchsia-600") == {"bg-fuchsia-600", nil}
    end

    test "nil and unknown atoms resolve to nil" do
      assert Theme.resolve(nil) == nil
      assert Theme.resolve(:no_such_token) == nil
    end

    test "configured tokens resolve by exact key, pair or bare bg" do
      with_tokens(%{"brand" => {"bg-[#5b21b6]", "text-white"}, muted: "bg-base-300"}, fn ->
        assert Theme.resolve("brand") == {"bg-[#5b21b6]", "text-white"}
        assert Theme.resolve(:muted) == {"bg-base-300", nil}
      end)
    end

    test "a configured token beats raw-string passthrough" do
      with_tokens(%{"bg-primary" => {"bg-secondary", nil}}, fn ->
        assert Theme.resolve("bg-primary") == {"bg-secondary", nil}
      end)
    end
  end

  describe "event_colors/2" do
    test "token pair wins, explicit text_color beats the pair" do
      event = %Event{id: 1, start: ~D[2026-04-01], color: :accent}
      assert Theme.event_colors(event) == {"bg-accent", "text-accent-content"}

      event = %Event{id: 1, start: ~D[2026-04-01], color: :accent, text_color: "text-black"}
      assert Theme.event_colors(event) == {"bg-accent", "text-black"}
    end

    test "no color falls back to the default bg with inferred text" do
      event = %Event{id: 1, start: ~D[2026-04-01]}
      {bg, text} = Theme.event_colors(event, "bg-primary/80")

      assert bg == "bg-primary/80"
      assert is_binary(text)
    end

    test "an unknown atom token falls back to the default bg" do
      event = %Event{id: 1, start: ~D[2026-04-01], color: :bogus}
      {bg, _text} = Theme.event_colors(event)

      assert bg == "bg-primary"
    end
  end

  describe "end-to-end rendering" do
    defp render(content), do: rendered_to_string(content)

    test "a token-colored event renders its resolved classes in the month grid" do
      events = [
        %Event{id: "1", start: ~D[2026-04-06], end: ~D[2026-04-09], title: "Trip", color: :accent}
      ]

      assigns = %{date: ~D[2026-04-01], events: events}

      html =
        render(~H"<PhoenixLiveCalendar.Views.MonthGrid.month_grid date={@date} events={@events} />")

      assert html =~ "bg-accent"
      assert html =~ "text-accent-content"
    end

    test "a configured custom token renders in the week grid's all-day row" do
      with_tokens(%{"brand" => {"bg-[#5b21b6]", "text-white"}}, fn ->
        events = [
          %Event{
            id: "1",
            start: ~D[2026-04-06],
            end: ~D[2026-04-08],
            title: "Launch",
            all_day: true,
            color: "brand"
          }
        ]

        assigns = %{dates: Enum.map(6..12, &Date.new!(2026, 4, &1)), events: events}

        html =
          render(
            ~H"<PhoenixLiveCalendar.Views.WeekGrid.week_grid dates={@dates} events={@events} />"
          )

        assert html =~ "bg-[#5b21b6]"
        assert html =~ "text-white"
      end)
    end

    test "raw class strings render exactly as before" do
      events = [
        %Event{
          id: "1",
          start: ~U[2026-04-06 10:00:00Z],
          end: ~U[2026-04-06 11:00:00Z],
          title: "Meeting",
          color: "bg-fuchsia-600",
          text_color: "text-white"
        }
      ]

      assigns = %{dates: [~D[2026-04-06]], events: events}

      html =
        render(~H"<PhoenixLiveCalendar.Views.WeekGrid.week_grid dates={@dates} events={@events} />")

      assert html =~ "bg-fuchsia-600"
      assert html =~ "text-white"
    end
  end
end
