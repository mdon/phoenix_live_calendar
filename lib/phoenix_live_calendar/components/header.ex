defmodule PhoenixLiveCalendar.Components.Header do
  @moduledoc """
  Calendar toolbar component with navigation, title, and view switcher.
  """

  use Phoenix.Component

  alias PhoenixLiveCalendar.Utils.I18n

  @doc """
  Renders the calendar header toolbar.

  ## Attributes

  - `title` — The title text (e.g., "April 2026")
  - `view` — Current view mode atom
  - `views` — List of available view modes (default: [:month, :week, :day])
  - `on_prev` — Event or JS command for previous navigation
  - `on_next` — Event or JS command for next navigation
  - `on_today` — Event or JS command for "go to today"
  - `on_view_change` — Event or JS command for view switching
  - `today_visible` — Whether today is in the current visible range (default: false)
  - `show_today_button` — Whether to show the today button at all (default: true).
    When `:auto`, the button is hidden if today is visible.
  - `translations` — Translation overrides
  - `class` — Additional CSS classes
  - `dir` — Text direction (:ltr or :rtl)

  ## Slots

  - `toolbar_start` — Custom content before the navigation
  - `toolbar_end` — Custom content after the view switcher
  """
  attr :title, :string, required: true
  attr :view, :atom, default: :month
  attr :views, :list, default: [:month, :week, :day]
  attr :on_prev, :any, required: true
  attr :on_next, :any, required: true
  attr :on_today, :any, required: true
  attr :on_view_change, :any, default: nil
  attr :today_visible, :boolean, default: false
  attr :show_today_button, :any, default: :auto
  attr :translations, :map, default: %{}
  attr :class, :string, default: ""
  attr :dir, :atom, default: :ltr
  attr :help_label, :string, default: "About"

  slot :toolbar_start
  slot :toolbar_end

  slot :help,
    doc:
      "Optional content for an info (ⓘ) disclosure shown at the end of the toolbar — e.g. a key explaining the calendar's markings. Rendered as a no-JS <details> popover."

  def header(assigns) do
    show_today =
      case assigns.show_today_button do
        :auto -> not assigns.today_visible
        true -> true
        false -> false
      end

    assigns = assign(assigns, :show_today, show_today)

    ~H"""
    <div
      class={[
        "cal-header grid grid-cols-[1fr_auto_1fr] items-center max-sm:gap-1 px-2 py-1.5 sm:px-3 sm:py-2",
        @class
      ]}
      role="toolbar"
      aria-label={I18n.label(:go_to_today, @translations)}
    >
      <%!-- Left: info disclosure + today button + custom slot --%>
      <div class="flex items-center gap-2 justify-self-start">
        <%!-- Info (ⓘ) disclosure: a no-JS <details> popover whose body is the
             consumer's `:help` slot (e.g. a key for the calendar's markings).
             Sits in the top-left corner. Inline SVG so the lib carries no
             icon-font dependency. --%>
        <details :if={@help != []} class="cal-help dropdown">
          <summary
            class="cal-help-toggle btn btn-sm btn-ghost btn-circle list-none [&::-webkit-details-marker]:hidden"
            aria-label={@help_label}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              class="w-5 h-5 opacity-60"
              aria-hidden="true"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="m11.25 11.25.041-.02a.75.75 0 0 1 1.063.852l-.708 2.836a.75.75 0 0 0 1.063.853l.041-.021M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9-3.75h.008v.008H12V8.25Z"
              />
            </svg>
          </summary>
          <div class="cal-help-content dropdown-content z-10 mt-1 w-72 rounded-box bg-base-200 p-3 text-xs leading-relaxed text-base-content/80 shadow-lg">
            {render_slot(@help)}
          </div>
        </details>

        {render_slot(@toolbar_start)}

        <button
          :if={@show_today}
          type="button"
          class="cal-nav-today btn btn-sm btn-ghost text-base-content/70 hover:text-base-content"
          phx-click={@on_today}
        >
          {I18n.label(:today, @translations)}
        </button>
      </div>

      <%!-- Center: ‹ Title › (always centered) --%>
      <div class="flex items-center gap-1 justify-self-center">
        <button
          type="button"
          class="cal-nav-prev btn btn-sm btn-ghost btn-circle"
          phx-click={@on_prev}
          aria-label={nav_label(:prev, @view, @translations)}
        >
          <span class={if @dir == :rtl, do: "cal-icon-next", else: "cal-icon-prev"}>
            &#8249;
          </span>
        </button>

        <h2
          class="cal-title text-sm sm:text-base font-semibold min-w-0 sm:min-w-32 max-w-[55vw] sm:max-w-none truncate text-center select-none"
          aria-live="polite"
        >
          {@title}
        </h2>

        <button
          type="button"
          class="cal-nav-next btn btn-sm btn-ghost btn-circle"
          phx-click={@on_next}
          aria-label={nav_label(:next, @view, @translations)}
        >
          <span class={if @dir == :rtl, do: "cal-icon-prev", else: "cal-icon-next"}>
            &#8250;
          </span>
        </button>
      </div>

      <%!-- Right: view switcher + custom slot --%>
      <div class="flex items-center gap-1 justify-self-end">
        <div
          :if={@on_view_change && length(@views) > 1}
          class="btn-group flex items-center gap-0.5"
          role="group"
        >
          <button
            :for={v <- @views}
            type="button"
            class={[
              "cal-view-btn btn btn-sm",
              if(v == @view, do: "btn-active btn-primary", else: "btn-ghost")
            ]}
            phx-click={@on_view_change}
            phx-value-view={view_value(v)}
            aria-pressed={to_string(v == @view)}
          >
            {view_label(v, @translations)}
          </button>
        </div>

        {render_slot(@toolbar_end)}
      </div>
    </div>
    """
  end

  # The serialized value the switcher button sends. A `{:n_day, n}` view is
  # a tuple — not attribute-safe — so it flattens to "n_day" (the component's
  # lc_view_change rehydrates the day count from its n_days attr).
  defp view_value({:n_day, _}), do: "n_day"
  defp view_value(v), do: to_string(v)

  defp view_label(:month, t), do: I18n.label(:month, t)
  defp view_label(:week, t), do: I18n.label(:week, t)
  defp view_label(:day, t), do: I18n.label(:day, t)
  defp view_label(:year, t), do: I18n.label(:year, t)
  defp view_label(:agenda, t), do: I18n.label(:agenda, t)
  defp view_label(:timeline, t), do: I18n.label(:timeline, t)
  defp view_label({:n_day, n}, _t), do: "#{n} Day"
  defp view_label(v, _t), do: to_string(v)

  defp nav_label(:prev, :month, t), do: I18n.label(:prev_month, t)
  defp nav_label(:next, :month, t), do: I18n.label(:next_month, t)
  defp nav_label(:prev, :week, t), do: I18n.label(:prev_week, t)
  defp nav_label(:next, :week, t), do: I18n.label(:next_week, t)
  defp nav_label(:prev, :day, t), do: I18n.label(:prev_day, t)
  defp nav_label(:next, :day, t), do: I18n.label(:next_day, t)
  defp nav_label(:prev, :year, t), do: I18n.label(:prev_year, t)
  defp nav_label(:next, :year, t), do: I18n.label(:next_year, t)
  defp nav_label(:prev, _, t), do: I18n.label(:prev, t)
  defp nav_label(:next, _, t), do: I18n.label(:next, t)
end
