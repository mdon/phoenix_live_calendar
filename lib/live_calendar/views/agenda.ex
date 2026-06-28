defmodule LiveCalendar.Views.Agenda do
  @moduledoc """
  Agenda/list view — displays events as a flat chronological list grouped by date.
  """

  use Phoenix.Component

  alias LiveCalendar.Event
  alias LiveCalendar.Utils.{DateHelpers, I18n}

  @doc """
  Renders an agenda/list view of events.

  ## Attributes

  - `date` — Start date for the agenda
  - `events` — List of `LiveCalendar.Event` structs
  - `days` — Number of days to show (default: 30)
  - `today` — Today's date
  - `on_event_click` — Handler for event clicks
  - `on_date_click` — Handler for date header clicks
  - `translations` — Translation overrides
  - `time_format` — `:h24` or `:h12` (default: `:h24`)
  - `show_empty_days` — Show days with no events (default: false)
  - `class` — Additional CSS classes

  ## Slots

  - `event` — Custom event rendering
  - `day_header` — Custom day header rendering. Receives `%{date: Date.t(), event_count: integer()}`.
  - `no_events` — Custom empty state content
  """
  attr :date, Date, required: true
  attr :events, :list, default: []
  attr :days, :integer, default: 30
  attr :today, Date, default: nil
  attr :on_event_click, :any, default: nil
  attr :on_date_click, :any, default: nil
  attr :translations, :map, default: %{}
  attr :time_format, :atom, default: :h24
  attr :show_empty_days, :boolean, default: false
  attr :class, :string, default: ""

  slot :event
  slot :day_header
  slot :no_events

  def agenda(assigns) do
    today = assigns.today || Date.utc_today()
    dates = DateHelpers.n_day_dates(assigns.date, assigns.days)

    events_by_date = DateHelpers.group_events_by_date(assigns.events, dates)

    # Filter out empty days unless show_empty_days is true
    grouped =
      dates
      |> Enum.map(fn date -> {date, Map.get(events_by_date, date, [])} end)
      |> maybe_filter_empty_days(assigns.show_empty_days)

    has_events = Enum.any?(grouped, fn {_, events} -> events != [] end)

    assigns =
      assigns
      |> assign(:today, today)
      |> assign(:grouped, grouped)
      |> assign(:has_events, has_events)

    ~H"""
    <div class={["cal-agenda", @class]} role="list" aria-label={I18n.label(:agenda, @translations)}>
      <%= if @has_events or @show_empty_days do %>
        <div :for={{date, day_events} <- @grouped} class="cal-agenda-day">
          <%!-- Day header --%>
          <%= if @day_header != [] do %>
            {render_slot(@day_header, %{date: date, event_count: length(day_events)})}
          <% else %>
            <.default_day_header
              date={date}
              today={@today}
              event_count={length(day_events)}
              on_date_click={@on_date_click}
              translations={@translations}
            />
          <% end %>

          <%!-- Events --%>
          <div class="cal-agenda-events divide-y divide-base-200">
            <div :for={event <- day_events} class="cal-agenda-event-row py-2 px-4">
              <%= if @event != [] do %>
                {render_slot(@event, event)}
              <% else %>
                <.default_agenda_event
                  event={event}
                  on_click={@on_event_click}
                  time_format={@time_format}
                />
              <% end %>
            </div>

            <div
              :if={day_events == [] and @show_empty_days}
              class="py-2 px-4 text-sm text-base-content/40"
            >
              {I18n.label(:no_events, @translations)}
            </div>
          </div>
        </div>
      <% else %>
        <%= if @no_events != [] do %>
          {render_slot(@no_events)}
        <% else %>
          <div class="cal-agenda-empty p-8 text-center text-base-content/50">
            {I18n.label(:no_events, @translations)}
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # -- Default sub-components --

  attr :date, Date, required: true
  attr :today, Date, required: true
  attr :event_count, :integer, required: true
  attr :on_date_click, :any, required: true
  attr :translations, :map, required: true

  defp default_day_header(assigns) do
    ~H"""
    <div class={[
      "cal-agenda-day-header sticky top-0 bg-base-100 px-4 py-2 border-b border-base-200 flex items-center gap-2",
      @date == @today && "bg-primary/5"
    ]}>
      <button
        :if={@on_date_click}
        type="button"
        class="hover:underline font-medium"
        phx-click={@on_date_click}
        phx-value-date={Date.to_iso8601(@date)}
      >
        {I18n.format_date(@date, @translations)}
      </button>
      <span :if={!@on_date_click} class="font-medium">
        {I18n.format_date(@date, @translations)}
      </span>

      <span :if={@date == @today} class="badge badge-primary badge-sm">
        {I18n.label(:today, @translations)}
      </span>

      <span class="text-xs text-base-content/40 ml-auto">
        {@event_count}
      </span>
    </div>
    """
  end

  attr :event, LiveCalendar.Event, required: true
  attr :on_click, :any, required: true
  attr :time_format, :atom, required: true

  defp default_agenda_event(assigns) do
    ~H"""
    <div
      class="flex items-center gap-3 cursor-pointer hover:bg-base-200/50 -mx-2 px-2 py-1 rounded"
      phx-click={@on_click}
      phx-value-event-id={@event.id}
      role="button"
      tabindex="0"
      aria-label={event_label(@event, @time_format)}
    >
      <div
        class={["w-3 h-3 rounded-full flex-shrink-0", @event.color || "bg-primary"]}
        aria-hidden="true"
      >
      </div>

      <div class="flex-1 min-w-0">
        <div class="font-medium text-sm truncate">
          {@event.title || "(No title)"}
        </div>
        <div :if={@event.location} class="text-xs text-base-content/60 truncate">
          {@event.location}
        </div>
      </div>

      <div class="text-sm text-base-content/60 flex-shrink-0">
        <%= if Event.all_day?(@event) do %>
          {I18n.label(:all_day)}
        <% else %>
          {format_time_range(@event, @time_format)}
        <% end %>
      </div>
    </div>
    """
  end

  defp maybe_filter_empty_days(groups, true = _show_empty), do: groups

  defp maybe_filter_empty_days(groups, _show_empty) do
    Enum.reject(groups, fn {_, events} -> events == [] end)
  end

  defp event_label(event, time_format) do
    title = event.title || "Untitled event"

    if Event.all_day?(event) do
      "#{title}, all day"
    else
      "#{title}, #{format_time_range(event, time_format)}"
    end
  end

  defp format_time_range(event, time_format) do
    start_str = format_event_time(event.start, time_format)
    end_str = format_event_time(Event.effective_end(event), time_format)
    "#{start_str} \u2013 #{end_str}"
  end

  defp format_event_time(%DateTime{} = dt, format),
    do: I18n.format_time(DateTime.to_time(dt), format: format)

  defp format_event_time(%NaiveDateTime{} = ndt, format),
    do: I18n.format_time(NaiveDateTime.to_time(ndt), format: format)

  defp format_event_time(_, _), do: ""
end
