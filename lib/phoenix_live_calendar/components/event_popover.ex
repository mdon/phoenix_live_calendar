defmodule PhoenixLiveCalendar.Components.EventPopover do
  @moduledoc """
  A popover/tooltip component for displaying event details on click or hover.

  Can be used standalone or integrated with the calendar views.
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils.I18n

  @doc """
  Renders an event detail popover.

  ## Attributes

  - `event` — The event to display details for
  - `show` — Whether the popover is visible (default: false)
  - `on_close` — Event handler to close the popover
  - `on_edit` — Optional edit handler
  - `on_delete` — Optional delete handler
  - `time_format` — `:h24` or `:h12` (default: `:h24`)
  - `class` — Additional CSS classes
  ## Slots

  - `inner_block` — Custom popover content. Receives the event.
  - `actions` — Custom action buttons
  """
  attr :event, PhoenixLiveCalendar.Event, default: nil
  attr :show, :boolean, default: false
  attr :on_close, :any, default: nil
  attr :on_edit, :any, default: nil
  attr :on_delete, :any, default: nil
  attr :time_format, :atom, default: :h24
  attr :class, :string, default: ""

  slot :inner_block
  slot :actions

  def event_popover(assigns) do
    ~H"""
    <div
      :if={@show && @event}
      id={"cal-popover-#{@event.id}"}
      class="cal-popover-backdrop fixed inset-0 z-50 flex items-center justify-center bg-base-content/30"
      role="dialog"
      aria-modal="true"
      aria-labelledby={"cal-popover-title-#{@event.id}"}
      phx-click={@on_close}
      phx-window-keydown={@on_close}
      phx-key="Escape"
      phx-hook="PopoverPause"
    >
      <div
        class={[
          "cal-popover bg-base-100 rounded-lg shadow-xl border border-base-300 p-4 min-w-64 max-w-80 relative",
          @class
        ]}
        phx-click-away={@on_close}
      >
        <%!-- Close button --%>
        <button
          :if={@on_close}
          type="button"
          class="absolute top-2 right-2 w-8 h-8 flex items-center justify-center rounded-full text-base-content/50 hover:text-base-content hover:bg-base-200 cursor-pointer transition-colors"
          phx-click={@on_close}
          aria-label="Close"
        >
          &times;
        </button>

        <%= if @inner_block != [] do %>
          {render_slot(@inner_block, @event)}
        <% else %>
          <.default_popover_content
            event={@event}
            time_format={@time_format}
            on_edit={@on_edit}
            on_delete={@on_delete}
            actions_slot={@actions}
          />
        <% end %>
      </div>
    </div>
    """
  end

  attr :event, PhoenixLiveCalendar.Event, required: true
  attr :time_format, :atom, required: true
  attr :on_edit, :any, required: true
  attr :on_delete, :any, required: true
  attr :actions_slot, :list, default: []

  defp default_popover_content(assigns) do
    ~H"""
    <div class="space-y-3">
      <%!-- Color bar + title --%>
      <div class="flex items-start gap-2">
        <div
          class={[
            "w-3 h-3 rounded-full mt-1 flex-shrink-0",
            PhoenixLiveCalendar.Theme.bg(@event.color) || "bg-primary"
          ]}
          aria-hidden="true"
        >
        </div>
        <div>
          <h3
            id={"cal-popover-title-#{@event.id}"}
            class={[
              "font-semibold text-base",
              @event.status in [:cancelled, :no_show] && "line-through text-base-content/50"
            ]}
          >
            {@event.title || "(No title)"}
          </h3>
          <.status_badge status={@event.status} />
        </div>
      </div>

      <%!-- Time --%>
      <div class="flex items-center gap-2 text-sm text-base-content/70">
        <span class="flex-shrink-0">&#128339;</span>
        <span>
          <%= if Event.all_day?(@event) do %>
            All day
          <% else %>
            {format_time(@event.start, @time_format)} &ndash; {format_time(
              Event.effective_end(@event),
              @time_format
            )}
          <% end %>
        </span>
      </div>

      <%!-- Location --%>
      <div :if={@event.location} class="flex items-center gap-2 text-sm text-base-content/70">
        <span class="flex-shrink-0">&#128205;</span>
        <span>{@event.location}</span>
      </div>

      <%!-- Description --%>
      <div :if={@event.description} class="text-sm text-base-content/70 border-t border-base-200 pt-2">
        {@event.description}
      </div>

      <%!-- Actions --%>
      <div
        :if={@on_edit || @on_delete || @actions_slot != []}
        class="flex items-center gap-2 pt-2 border-t border-base-200"
      >
        <%= if @actions_slot != [] do %>
          {render_slot(@actions_slot, @event)}
        <% else %>
          <button
            :if={@on_edit && @event.editable}
            type="button"
            class="btn btn-sm btn-ghost"
            phx-click={@on_edit}
            phx-value-event-id={@event.id}
          >
            Edit
          </button>
          <button
            :if={@on_delete && @event.editable}
            type="button"
            class="btn btn-sm btn-ghost text-error"
            phx-click={@on_delete}
            phx-value-event-id={@event.id}
          >
            Delete
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <span
      :if={@status != :confirmed}
      class={[
        "inline-block text-xs px-1.5 py-0.5 rounded",
        status_badge_class(@status)
      ]}
    >
      {status_label(@status)}
    </span>
    """
  end

  defp status_badge_class(:tentative), do: "bg-warning/20 text-warning"
  defp status_badge_class(:cancelled), do: "bg-error/20 text-error"
  defp status_badge_class(:pending_approval), do: "bg-info/20 text-info"
  defp status_badge_class(:no_show), do: "bg-error/20 text-error"
  defp status_badge_class(_), do: "bg-base-200"

  defp status_label(:tentative), do: "Tentative"
  defp status_label(:cancelled), do: "Cancelled"
  defp status_label(:pending_approval), do: "Pending Approval"
  defp status_label(:no_show), do: "No Show"
  defp status_label(status), do: to_string(status)

  defp format_time(%DateTime{} = dt, format),
    do: I18n.format_time(DateTime.to_time(dt), format: format)

  defp format_time(%NaiveDateTime{} = ndt, format),
    do: I18n.format_time(NaiveDateTime.to_time(ndt), format: format)

  defp format_time(%Time{} = t, format),
    do: I18n.format_time(t, format: format)

  defp format_time(_, _), do: ""
end
