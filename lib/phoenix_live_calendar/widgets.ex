defmodule PhoenixLiveCalendar.Widgets do
  @moduledoc """
  The most compressed genuinely-useful form of each calendar surface — for
  dashboard cells, sidebars, and anywhere a full view has no room
  (~200×150px and up).

  Below panel size the ENCODING has to change, not just the type scale, so
  these are dedicated components rather than shrunken grids:

  - `next_events/1` — the viewer's next N events as a compact list. The
    single highest-value calendar widget.
  - `week_strip/1` — seven day cells with event dots/counts; replaces an
    illegible miniature time grid.
  - `activity_grid/1` — the GitHub-style contributions strip (weeks ×
    weekdays) over `Heatmap` data.
  - `activity_month/1` — the same square encoding for ONE month, in
    calendar orientation (weekday columns, week rows).
  - `mini_timeline/1` — a preset-compressed `Timeline` (fitted window, no
    labels, tiny slots) for a peek at today's sessions.

  For a compact MONTH, use `PhoenixLiveCalendar.Components.MiniCalendar`
  (optionally with heatmap `markers_by_date`) — it already is the widget
  form.
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.{Event, Heatmap, Theme}
  alias PhoenixLiveCalendar.Utils.{DateHelpers, I18n}
  alias PhoenixLiveCalendar.Views.Timeline

  @doc """
  The next `limit` events, soonest first, as a compact list.

  - `events` — the pool to pick from (pass whatever you have; ended events
    are dropped: timed ones by comparing `effective_end` to `now`, all-day
    ones once their last date is past)
  - `now` — the reference instant (default `DateTime.utc_now()`); pass the
    viewer's local time for timezone-correct "Today" grouping
  - `within_days` — horizon (default 14)
  - Each row: color dot (the event's resolved color), truncated title, and
    a short when-label — the time for today's events, the weekday within a
    week, the date beyond that.
  """
  attr :events, :list, required: true
  attr :now, DateTime, default: nil
  attr :limit, :integer, default: 3
  attr :within_days, :integer, default: 14
  attr :on_event_click, :any, default: nil
  attr :time_format, :atom, default: :h24
  attr :translations, :map, default: %{}
  attr :class, :string, default: ""

  def next_events(assigns) do
    now = assigns.now || DateTime.utc_now()
    today = DateTime.to_date(now)
    horizon = Date.add(today, assigns.within_days)

    upcoming =
      assigns.events
      |> Enum.filter(fn event ->
        not ended?(event, now) and Date.compare(Event.first_date(event), horizon) != :gt
      end)
      |> Enum.sort_by(&sort_key/1)
      |> Enum.take(assigns.limit)

    assigns = assigns |> assign(:upcoming, upcoming) |> assign(:today, today)

    ~H"""
    <div class={["cal-widget cal-next-events text-xs", @class]}>
      <div
        :if={@upcoming == []}
        class="cal-widget-empty text-base-content/50 py-2 text-center"
      >
        {I18n.label(:no_events, @translations)}
      </div>
      <ul :if={@upcoming != []} class="divide-y divide-base-200">
        <li :for={event <- @upcoming}>
          <button
            type="button"
            class="flex w-full items-center gap-1.5 py-1 text-start disabled:cursor-default"
            disabled={is_nil(@on_event_click)}
            phx-click={@on_event_click}
            phx-value-event-id={event.id}
          >
            <span
              class={["w-2 h-2 rounded-full flex-shrink-0", event_dot(event)]}
              aria-hidden="true"
            >
            </span>
            <span class="cal-widget-title flex-1 min-w-0 truncate font-medium">
              {event.title || "(No title)"}
            </span>
            <span class="cal-widget-when text-base-content/60 whitespace-nowrap tabular-nums">
              {when_label(event, @today, @time_format, @translations)}
            </span>
          </button>
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  Seven day cells — narrow day letter, day number, up to three event dots
  (a `+N` count beyond that). The week-at-a-glance replacement for a time
  grid that would be illegible at widget size.
  """
  attr :date, Date, default: nil, doc: "any date inside the week (default: today)"
  attr :events, :list, default: []
  attr :today, Date, default: nil
  attr :week_start, :integer, default: 1
  attr :on_date_click, :any, default: nil
  attr :translations, :map, default: %{}
  attr :class, :string, default: ""

  def week_strip(assigns) do
    today = assigns.today || Date.utc_today()
    anchor = assigns.date || today
    monday = DateHelpers.week_start_date(anchor, assigns.week_start)
    dates = Enum.map(0..6, &Date.add(monday, &1))
    events_by_date = DateHelpers.group_events_by_date(assigns.events, dates)

    assigns =
      assigns
      |> assign(:today, today)
      |> assign(:dates, dates)
      |> assign(:events_by_date, events_by_date)

    ~H"""
    <div class={["cal-widget cal-week-strip grid grid-cols-7 gap-0.5 text-center text-xs", @class]}>
      <button
        :for={date <- @dates}
        type="button"
        class="cal-week-strip-day flex flex-col items-center gap-0.5 rounded py-1 hover:bg-base-200 disabled:cursor-default disabled:hover:bg-transparent"
        disabled={is_nil(@on_date_click)}
        phx-click={@on_date_click}
        phx-value-date={Date.to_iso8601(date)}
        aria-current={if(date == @today, do: "date")}
      >
        <span class="text-[0.6rem] text-base-content/50 leading-none">
          {I18n.day_name_narrow(Date.day_of_week(date), @translations)}
        </span>
        <span class={[
          "w-5 h-5 rounded-full leading-5",
          date == @today && "bg-primary text-primary-content font-bold"
        ]}>
          {date.day}
        </span>
        <span class="flex h-2 items-center gap-0.5">
          <%= case Map.get(@events_by_date, date, []) do %>
            <% [] -> %>
            <% events when length(events) <= 3 -> %>
              <span
                :for={event <- events}
                class={["w-1 h-1 rounded-full", event_dot(event)]}
                aria-hidden="true"
              >
              </span>
            <% events -> %>
              <span class="text-[0.55rem] leading-none text-base-content/60">
                +{length(events)}
              </span>
          <% end %>
        </span>
      </button>
    </div>
    """
  end

  @doc """
  A GitHub-contributions strip: `weeks` columns × 7 weekday rows of tiny
  intensity squares over `Heatmap` data (`Date => number`).

  - `data` — the per-day numbers; `palette`/`scale`/`max` behave as in
    `PhoenixLiveCalendar.Heatmap.markers/2`
  - `to` — last day shown (default: today); the strip covers the
    `weeks * 7` days ending there, aligned to `week_start`
  - Each active square carries a `title` tooltip with the date and value.
  """
  attr :data, :any, required: true
  attr :to, Date, default: nil
  attr :weeks, :integer, default: 26
  attr :week_start, :integer, default: 1
  attr :palette, :any, default: :success
  attr :scale, :atom, default: :linear
  attr :max, :any, default: nil
  attr :cell_class, :string, default: "w-1.5 h-1.5 rounded-[2px]"
  attr :class, :string, default: ""

  def activity_grid(assigns) do
    to = assigns.to || Date.utc_today()
    week_end = Date.add(DateHelpers.week_start_date(to, assigns.week_start), 6)
    first = Date.add(week_end, -(assigns.weeks * 7 - 1))

    classes =
      Heatmap.classes(assigns.data,
        palette: assigns.palette,
        scale: assigns.scale,
        max: assigns.max
      )

    days = Date.range(first, week_end)

    assigns =
      assigns
      |> assign(:days, days)
      |> assign(:classes, classes)

    ~H"""
    <div
      class={["cal-widget cal-activity-grid grid grid-rows-7 grid-flow-col gap-0.5 w-max", @class]}
      role="img"
      aria-label="Activity"
    >
      <span
        :for={day <- @days}
        class={[
          "cal-activity-cell",
          @cell_class,
          case Map.get(@classes, day) do
            %{class: class} -> class
            nil -> "bg-base-content/8"
          end
        ]}
        title={activity_title(day, Map.get(@classes, day))}
      >
      </span>
    </div>
    """
  end

  @doc """
  One month of activity squares in calendar orientation — the
  `activity_grid/1` encoding at month scale: weekday columns, one row per
  week, out-of-month days blank, today ringed.

  - `data` — per-day numbers; `palette`/`scale`/`max` as in
    `PhoenixLiveCalendar.Heatmap.markers/2`
  - `date` — any date inside the month (default: today)
  - `show_day_initials` — narrow weekday initials above the columns
    (default `true`)
  """
  attr :data, :any, required: true
  attr :date, Date, default: nil
  attr :today, Date, default: nil
  attr :week_start, :integer, default: 1
  attr :palette, :any, default: :success
  attr :scale, :atom, default: :linear
  attr :max, :any, default: nil
  attr :cell_class, :string, default: "w-3 h-3 rounded-[3px]"
  attr :show_day_initials, :boolean, default: true
  attr :translations, :map, default: %{}
  attr :class, :string, default: ""

  def activity_month(assigns) do
    today = assigns.today || Date.utc_today()
    anchor = assigns.date || today
    dates = DateHelpers.month_grid(anchor, week_start: assigns.week_start, fixed_weeks: false)

    classes =
      Heatmap.classes(assigns.data,
        palette: assigns.palette,
        scale: assigns.scale,
        max: assigns.max
      )

    day_initials = I18n.ordered_day_names_narrow(assigns.week_start, assigns.translations)

    assigns =
      assigns
      |> assign(:today, today)
      |> assign(:anchor, anchor)
      |> assign(:dates, dates)
      |> assign(:classes, classes)
      |> assign(:day_initials, day_initials)

    ~H"""
    <div
      class={["cal-widget cal-activity-month grid grid-cols-7 gap-0.5 w-max", @class]}
      role="img"
      aria-label="Activity"
    >
      <span
        :for={initial <- @day_initials}
        :if={@show_day_initials}
        class="cal-activity-day-initial text-[0.6rem] leading-none text-base-content/50 text-center"
      >
        {initial}
      </span>
      <span
        :for={day <- @dates}
        class={[
          "cal-activity-cell",
          @cell_class,
          not DateHelpers.in_month?(day, @anchor) && "invisible",
          case Map.get(@classes, day) do
            %{class: class} -> class
            nil -> "bg-base-content/8"
          end,
          day == @today && "ring-1 ring-primary"
        ]}
        title={activity_title(day, Map.get(@classes, day))}
      >
      </span>
    </div>
    """
  end

  @doc """
  A preset-compressed `Timeline`: fitted window, no time axis, no bar
  labels (tooltips remain), tiny slots, at most `max_rows` resources.
  """
  attr :id, :string, default: "mini-timeline"
  attr :date, Date, required: true
  attr :resources, :list, required: true
  attr :events, :list, default: []
  attr :max_rows, :integer, default: 3
  attr :resource_width, :string, default: "6rem"
  attr :today, Date, default: nil
  attr :now, Time, default: nil
  attr :on_event_click, :any, default: nil
  attr :class, :string, default: ""

  def mini_timeline(assigns) do
    ~H"""
    <Timeline.timeline
      id={@id}
      date={@date}
      resources={Enum.take(@resources, @max_rows)}
      events={@events}
      today={@today}
      now={@now}
      fit_to_events={true}
      show_time_axis={false}
      label_position={:none}
      sticky_resource_column={false}
      slot_duration={60}
      slot_width="2rem"
      resource_width={@resource_width}
      on_event_click={@on_event_click}
      class={"cal-widget cal-mini-timeline #{@class}"}
    />
    """
  end

  # -- helpers --

  defp ended?(event, now) do
    case Event.effective_end(event) do
      %Date{} -> Date.compare(Event.last_date(event), DateTime.to_date(now)) == :lt
      %DateTime{} = dt -> DateTime.compare(dt, now) != :gt
      %NaiveDateTime{} = ndt -> NaiveDateTime.compare(ndt, DateTime.to_naive(now)) != :gt
    end
  end

  defp sort_key(event) do
    {Date.to_gregorian_days(Event.first_date(event)), start_time_key(event.start)}
  end

  defp start_time_key(%Date{}), do: ~T[00:00:00]
  defp start_time_key(%DateTime{} = dt), do: DateTime.to_time(dt)
  defp start_time_key(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_time(ndt)

  defp event_dot(event) do
    Theme.bg(event.color) || "bg-primary"
  end

  # Today's events show their time; this week's the weekday; further out
  # the date.
  defp when_label(event, today, time_format, translations) do
    start_date = Event.first_date(event)

    cond do
      Event.all_day?(event) and start_date == today ->
        I18n.label(:all_day, translations)

      start_date == today ->
        I18n.format_time(start_time_key(event.start), format: time_format)

      Date.diff(start_date, today) < 7 ->
        I18n.day_name_short(Date.day_of_week(start_date), translations)

      true ->
        "#{I18n.month_name_short(start_date.month, translations)} #{start_date.day}"
    end
  end

  defp activity_title(day, nil), do: Date.to_iso8601(day)
  defp activity_title(day, %{value: value}), do: "#{Date.to_iso8601(day)} — #{value}"
end
