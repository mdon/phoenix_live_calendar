defmodule PhoenixLiveCalendar.Components.EventItem do
  @moduledoc """
  Renders a single event within a calendar cell or time grid.

  Supports status-based styling (confirmed, tentative, cancelled, pending approval),
  urgency indicators (attention, warning, critical with animated borders),
  priority visual weight, and custom rendering via slots.
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils.{I18n, Safe}

  @doc """
  Renders an event element with status-aware styling.

  ## Attributes

  - `event` — A `PhoenixLiveCalendar.Event` struct
  - `on_click` — Event handler when the event is clicked
  - `compact` — Render in compact mode (title only, no time)
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
  attr :class, :string, default: ""
  attr :time_format, :atom, default: :h24

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
    ~H"""
    <div
      id={event_dom_id(@event, @id_suffix)}
      class={[
        "cal-event",
        event_base_class(@event),
        status_class(@event),
        not @compact && urgency_class(@event),
        not @compact && priority_class(@event),
        @event.color,
        @event.text_color || Safe.infer_text_color(@event.color),
        @event.class,
        not @compact && border_color_class(@event),
        @on_click && "cursor-pointer hover:brightness-95",
        @class
      ]}
      role="button"
      tabindex="0"
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
        <.default_event_content event={@event} compact={@compact} time_format={@time_format} />
      <% end %>
    </div>
    """
  end

  attr :event, PhoenixLiveCalendar.Event, required: true
  attr :compact, :boolean, default: false
  attr :time_format, :atom, default: :h24

  defp default_event_content(assigns) do
    ~H"""
    <div class="cal-event-content flex items-center gap-1 overflow-hidden text-xs">
      <%!-- Priority indicator dot (hidden in compact/month view) --%>
      <span
        :if={not @compact and @event.priority in [:high, :urgent]}
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
        :if={not @compact and not Event.all_day?(@event) and @event.start}
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
  defp border_color_class(%Event{border_color: color}), do: "border-l-4 #{color}"

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
