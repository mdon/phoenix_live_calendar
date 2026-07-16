defmodule PhoenixLiveCalendar.Components.EventItem do
  @moduledoc """
  Renders a single event within a calendar cell or time grid.

  Supports status-based styling (confirmed, tentative, cancelled, pending approval),
  urgency indicators (attention, warning, critical with animated borders),
  priority visual weight, and custom rendering via slots.
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils.I18n

  @doc """
  Renders an event element with status-aware styling.

  ## Attributes

  - `event` — A `PhoenixLiveCalendar.Event` struct
  - `on_click` — Event handler when the event is clicked
  - `compact` — Render in compact mode (title only, no time)
  - `content` — how much to render: `:detail` / `:inline` (default) /
    `:title` / `:none` — the time grids pick a tier from the block's
    estimated height (`tier_for_height/1`)
  - `default_color` — background when the event has no `color` of its own
  - `id_suffix` — disambiguates the DOM id when the same event renders more
    than once on a page (per-date / per-resource / per-view-instance)
  - `class` — Additional CSS classes
  - `time_format` — `:h24` or `:h12` (default: `:h24`)

  ## Status styling

  - `:confirmed` — solid background (default)
  - `:tentative` — dashed border, reduced opacity
  - `:cancelled` — strikethrough text, ghost styling
  - `:pending_approval` — pulsing border animation
  - `:no_show` — red-tinted, strikethrough

  ## Urgency indicators

  - `:none` — no special indicator (default)
  - `:attention` — subtle pulsing border
  - `:warning` — yellow/amber animated border
  - `:critical` — red animated border, more prominent

  ## Slots

  - `inner_block` — Custom event rendering. Receives the event as a slot argument.
  """
  attr :event, PhoenixLiveCalendar.Event, required: true
  attr :on_click, :any, default: nil
  attr :compact, :boolean, default: false

  attr :content, :atom,
    default: :inline,
    values: [:detail, :inline, :title, :none],
    doc: """
    How much of the event to render, chosen by the caller (the time grids
    compute it from the block's estimated height so text never clips
    mid-glyph): `:detail` = stacked title / start–end range / location;
    `:inline` = one line of time + title (the classic layout); `:title` =
    title only; `:none` = colored block only — the native `title` tooltip
    and aria-label still identify it.
    """

  attr :class, :string, default: ""
  attr :time_format, :atom, default: :h24

  attr :default_color, :string,
    default: "bg-primary",
    doc: """
    Background applied when the event has no `color` of its own, so a
    color-less event is always legible (previously it rendered with NO
    background while `infer_text_color(nil)` assumed a primary one —
    white text on the naked cell). The event's own `color` always wins.
    """

  attr :id_suffix, :any,
    default: nil,
    doc: """
    Disambiguates the DOM id when the SAME event renders more than once in
    one view — a midnight-crossing timed event occupies two month/week day
    cells, and a multi-resource event renders once per resource column.
    Callers rendering events inside a per-date/per-resource loop pass the
    loop key here; without it LiveView reports duplicate DOM ids and
    morphdom patching misbehaves.
    """

  slot :inner_block

  def event_item(assigns) do
    {bg, text} = PhoenixLiveCalendar.Theme.event_colors(assigns.event, assigns.default_color)
    assigns = assigns |> assign(:event_bg, bg) |> assign(:event_text, text)

    ~H"""
    <div
      id={event_dom_id(@event, @id_suffix)}
      class={[
        "cal-event",
        event_base_class(@event),
        status_class(@event),
        not @compact && urgency_class(@event),
        not @compact && priority_class(@event),
        @event_bg,
        @event_text,
        @event.class,
        not @compact && border_color_class(@event),
        @on_click && "cursor-pointer hover:brightness-95",
        @class
      ]}
      role="button"
      tabindex="0"
      title={@event.title}
      aria-label={event_aria_label(@event, @time_format)}
      phx-click={@on_click}
      phx-value-event-id={@event.id}
      data-event-id={@event.id}
      data-editable={to_string(@event.editable)}
      data-status={@event.status}
      data-priority={@event.priority}
      data-urgency={@event.urgency}
      data-all-day={to_string(Event.all_day?(@event))}
    >
      <%= if @inner_block != [] do %>
        {render_slot(@inner_block, @event)}
      <% else %>
        <.default_event_content
          event={@event}
          content={if @compact and @content != :none, do: :title, else: @content}
          time_format={@time_format}
        />
      <% end %>
    </div>
    """
  end

  # Content-tier thresholds: the minimum estimated block height (rem) for
  # each layout. 3.25rem fits three text-xs lines + padding; 1.75 two; 1.25
  # one. Shared by every time grid so the ladder can't drift between views.
  @detail_min_rem 3.25
  @inline_min_rem 1.75
  @title_min_rem 1.25

  @doc """
  Per-view-instance suffix for event DOM ids: two views rendering the same
  events on one page pass their own `id` so per-event ids can't collide.
  """
  @spec instance_suffix(String.t() | nil, String.t() | term()) :: String.t() | term()
  def instance_suffix(nil, key), do: key
  def instance_suffix(id, key), do: "#{id}-#{key}"

  @doc """
  The content tier for an event block of an estimated height (rem):
  `:detail` ≥ #{@detail_min_rem}, `:inline` ≥ #{@inline_min_rem},
  `:title` ≥ #{@title_min_rem}, else `:none` — whole text lines or none.
  """
  @spec tier_for_height(number()) :: :detail | :inline | :title | :none
  def tier_for_height(h_rem) do
    cond do
      h_rem >= @detail_min_rem -> :detail
      h_rem >= @inline_min_rem -> :inline
      h_rem >= @title_min_rem -> :title
      true -> :none
    end
  end

  attr :event, PhoenixLiveCalendar.Event, required: true
  attr :content, :atom, default: :inline
  attr :time_format, :atom, default: :h24

  # :none — the block is just color; the outer div's title/aria identify it.
  defp default_event_content(%{content: :none} = assigns) do
    ~H""
  end

  # :detail — a stacked layout for the taller week/day blocks: title first
  # (always visible), then the time RANGE, then the location.
  defp default_event_content(%{content: :detail} = assigns) do
    ~H"""
    <div class="cal-event-content cal-event-detail flex flex-col overflow-hidden text-xs h-full">
      <div class="flex items-center gap-1 min-w-0">
        <span
          :if={@event.priority in [:high, :urgent]}
          class={[
            "cal-event-priority w-1.5 h-1.5 rounded-full flex-shrink-0",
            priority_dot_class(@event)
          ]}
          aria-hidden="true"
        >
        </span>
        <span
          :if={@event.badge}
          class="cal-event-badge text-[0.6rem] font-bold uppercase px-1 rounded bg-base-content/10"
        >
          {@event.badge}
        </span>
        <span :if={@event.icon} class="cal-event-icon flex-shrink-0" aria-hidden="true">
          {@event.icon}
        </span>
        <span class={[
          "cal-event-title truncate font-medium",
          @event.status in [:cancelled, :no_show] && "line-through"
        ]}>
          {@event.title || "(No title)"}
        </span>
      </div>

      <span
        :if={not Event.all_day?(@event) and @event.start}
        class="cal-event-time whitespace-nowrap opacity-90"
      >
        {format_event_time(@event.start, @time_format)} – {format_event_time(
          Event.effective_end(@event),
          @time_format
        )}
      </span>

      <span :if={@event.location} class="cal-event-location truncate text-[0.65rem] opacity-80">
        {@event.location}
      </span>
    </div>
    """
  end

  defp default_event_content(assigns) do
    ~H"""
    <div class="cal-event-content flex items-center gap-1 overflow-hidden text-xs">
      <%!-- Priority indicator dot (hidden in title-only/month view) --%>
      <span
        :if={@content == :inline and @event.priority in [:high, :urgent]}
        class={["cal-event-priority w-1.5 h-1.5 rounded-full flex-shrink-0", priority_dot_class(@event)]}
        aria-hidden="true"
      >
      </span>

      <%!-- Badge (e.g., "NEW", "APPROVED", custom text) --%>
      <span
        :if={@event.badge}
        class="cal-event-badge text-[0.6rem] font-bold uppercase px-1 rounded bg-base-content/10"
      >
        {@event.badge}
      </span>

      <%!-- Time --%>
      <span
        :if={@content == :inline and not Event.all_day?(@event) and @event.start}
        class="cal-event-time font-medium whitespace-nowrap"
      >
        {format_event_time(@event.start, @time_format)}
      </span>

      <%!-- Icon (heroicon name or custom) --%>
      <span :if={@event.icon} class="cal-event-icon flex-shrink-0" aria-hidden="true">
        {@event.icon}
      </span>

      <%!-- Title --%>
      <span class={[
        "cal-event-title truncate font-medium",
        @event.status in [:cancelled, :no_show] && "line-through"
      ]}>
        {@event.title || "(No title)"}
      </span>
    </div>
    """
  end

  # -- Status-based classes --

  defp status_class(%Event{status: :confirmed}), do: nil
  defp status_class(%Event{status: :tentative}), do: "cal-status-tentative opacity-70 border-dashed"
  defp status_class(%Event{status: :cancelled}), do: "cal-status-cancelled opacity-50"
  defp status_class(%Event{status: :pending_approval}), do: "cal-status-pending animate-pulse"
  defp status_class(%Event{status: :no_show}), do: "cal-status-noshow opacity-60 bg-error/20"
  defp status_class(_), do: nil

  # -- Urgency animation classes --

  defp urgency_class(%Event{urgency: :none}), do: nil

  defp urgency_class(%Event{urgency: :attention}),
    do: "cal-urgency-attention ring-1 ring-info/50 animate-pulse"

  defp urgency_class(%Event{urgency: :warning}),
    do:
      "cal-urgency-warning ring-2 ring-warning animate-[cal-pulse-warning_2s_ease-in-out_infinite]"

  defp urgency_class(%Event{urgency: :critical}),
    do:
      "cal-urgency-critical ring-2 ring-error animate-[cal-pulse-critical_1s_ease-in-out_infinite]"

  defp urgency_class(_), do: nil

  # -- Priority visual weight --

  defp priority_class(%Event{priority: :low}), do: "cal-priority-low opacity-80"
  defp priority_class(%Event{priority: :normal}), do: nil
  defp priority_class(%Event{priority: :high}), do: "cal-priority-high font-semibold"
  defp priority_class(%Event{priority: :urgent}), do: "cal-priority-urgent font-bold"
  defp priority_class(_), do: nil

  defp priority_dot_class(%Event{priority: :high}), do: "bg-warning"
  defp priority_dot_class(%Event{priority: :urgent}), do: "bg-error"
  defp priority_dot_class(_), do: nil

  # -- Border color (for custom attention indicators) --

  defp border_color_class(%Event{border_color: nil}), do: nil
  defp border_color_class(%Event{border_color: color}), do: "border-s-4 #{color}"

  # -- Base display class --

  defp event_dom_id(event, nil), do: "cal-event-#{event.id}"
  defp event_dom_id(event, suffix), do: "cal-event-#{event.id}-#{suffix}"

  defp event_base_class(%Event{} = event) do
    cond do
      event.display == :background -> "cal-event-bg opacity-30"
      Event.all_day?(event) -> "cal-event-allday rounded px-1 py-0.5"
      true -> "cal-event-timed rounded px-1 py-0.5"
    end
  end

  # -- ARIA --

  defp event_aria_label(%Event{} = event, time_format) do
    title = event.title || "Untitled event"
    status_part = aria_status_text(event.status)
    time_part = aria_time_text(event, time_format)

    [title, status_part, time_part]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
  end

  defp aria_status_text(:confirmed), do: nil
  defp aria_status_text(:tentative), do: "tentative"
  defp aria_status_text(:cancelled), do: "cancelled"
  defp aria_status_text(:pending_approval), do: "pending approval"
  defp aria_status_text(:no_show), do: "no show"
  defp aria_status_text(_), do: nil

  defp aria_time_text(event, time_format) do
    if Event.all_day?(event) do
      "all day"
    else
      end_time = event.end || Event.effective_end(event)

      "#{format_event_time(event.start, time_format)} to #{format_event_time(end_time, time_format)}"
    end
  end

  # -- Time formatting --

  defp format_event_time(%DateTime{} = dt, format),
    do: I18n.format_time(DateTime.to_time(dt), format: format)

  defp format_event_time(%NaiveDateTime{} = ndt, format),
    do: I18n.format_time(NaiveDateTime.to_time(ndt), format: format)

  defp format_event_time(%Time{} = t, format),
    do: I18n.format_time(t, format: format)

  defp format_event_time(%Date{}, _format), do: ""
  defp format_event_time(_, _format), do: ""
end
