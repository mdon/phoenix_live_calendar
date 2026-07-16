defmodule PhoenixLiveCalendar.CalendarComponent do
  @moduledoc """
  The main calendar LiveComponent.

  Manages internal state (current date, view mode, navigation) and renders
  the appropriate view. Communicates with the parent via callback functions.

  ## Usage

      <.live_component
        module={PhoenixLiveCalendar.CalendarComponent}
        id="my-calendar"
        events={@events}
        on_date_select={fn date -> send(self(), {:date_selected, date}) end}
        on_event_click={fn event_id -> send(self(), {:event_clicked, event_id}) end}
      />

  ## Full example with all options

      <.live_component
        module={PhoenixLiveCalendar.CalendarComponent}
        id="booking-calendar"
        events={@events}
        resources={@resources}
        view={:week}
        views={[:day, :week, :month]}
        date={@current_date}
        selected_date={@selected_date}
        week_start={1}
        min_time={~T[08:00:00]}
        max_time={~T[20:00:00]}
        slot_duration={15}
        time_format={:h12}
        business_hours={@business_hours}
        translations={%{labels: %{today: "Aujourd'hui"}}}
        dir={:ltr}
        on_date_select={fn date -> send(self(), {:date_selected, date}) end}
        on_range_select={fn range -> send(self(), {:range_selected, range}) end}
        on_event_click={fn event_id -> send(self(), {:event_clicked, event_id}) end}
        on_event_drop={fn data -> send(self(), {:event_dropped, data}) end}
        on_view_change={fn data -> send(self(), {:view_changed, data}) end}
      />

  ## Slots

  The underlying views' customization slots are forwarded through the
  component — pass them as `<.live_component>` children:

      <.live_component module={PhoenixLiveCalendar.CalendarComponent} id="cal" events={@events}>
        <:event :let={event}>
          <.my_event_chip event={event} />
        </:event>
      </.live_component>

  - `:event` — custom event rendering (month, week, day, N-day, agenda,
    timeline, resource)
  - `:day_cell` — full month day-cell replacement (receives
    `%{date: date, events: events, markers: markers}`)
  - `:time_label` — time gutter labels (week, day, N-day)
  - `:resource_label` / `:resource_header` — timeline / resource column labels
  - `:day_header` / `:no_events` — agenda day headings and empty state
  - `:info` — toolbar info (ⓘ) disclosure content
  """

  use Phoenix.LiveComponent

  require Logger

  # Compile-time check: warn if CSS integration hasn't been installed
  unless Application.compile_env(:phoenix_live_calendar, :skip_install_check, false) do
    unless PhoenixLiveCalendar.installed?() do
      IO.warn("""
      PhoenixLiveCalendar CSS integration not detected.

      Tailwind will not scan PhoenixLiveCalendar's component templates, so styles
      (including rounded corners, colors, and layout) will be missing.

      Run:  mix phoenix_live_calendar.install

      To suppress this warning, add to your config:

          config :phoenix_live_calendar, skip_install_check: true
      """)
    end
  end

  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Utils.{DateHelpers, I18n, Safe, Telemetry}

  alias PhoenixLiveCalendar.Views.{
    Agenda,
    DayView,
    MonthGrid,
    NDayView,
    ResourceView,
    Timeline,
    WeekGrid,
    YearView
  }

  alias PhoenixLiveCalendar.Components.Header

  # -- Mount --

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign_new(:internal_view, fn -> :month end)
     # Last parent-provided :date / :view, tracked so we can tell an actual
     # parent-driven change apart from a routine re-render passing the same value.
     |> assign_new(:last_date_prop, fn -> nil end)
     |> assign_new(:last_view_prop, fn -> nil end)}
  end

  # -- Update --

  @impl true
  def update(assigns, socket) do
    # Profile incoming events on every data update (cheap, always runs once)
    assigns = maybe_profile_ingress(assigns, socket)

    # On first render or when parent pushes a new date/view, sync internal state.
    # `internal_date` is seeded HERE, not in mount/1: a LiveComponent's mount
    # can't see parent assigns, and a timezone-correct `today` (without an
    # explicit `date`) must win over the server's UTC today — otherwise a
    # viewer east of UTC opens the calendar on the wrong month late evening.
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:internal_date, fn ->
        assigns[:date] || assigns[:today] || Date.utc_today()
      end)
      # Initial layer visibility comes from Layer.visible on the FIRST layers
      # list; after that the component owns the toggles.
      |> assign_new(:hidden_layer_ids, fn ->
        (assigns[:layers] || [])
        |> Enum.reject(& &1.visible)
        |> MapSet.new(&to_string(&1.id))
      end)
      |> maybe_sync_date(assigns)
      |> maybe_sync_view(assigns)

    {:ok, socket}
  end

  # `:date` and `:view` act as the INITIAL anchor AND a controlled override:
  # sync internal state on first mount and whenever the parent actually CHANGES
  # the value, but ignore a re-render that passes the same value as last time —
  # otherwise a routine parent re-render (a PubSub reload, a sibling assign
  # change) would snap the calendar back, discarding the user's own navigation.
  # `internal_date`/`internal_view` are owned by the component's nav events
  # (lc_navigate / lc_today / lc_view_change); the `last_*_prop` assigns track
  # only what the parent last sent so we can diff against it.
  defp maybe_sync_date(socket, %{date: date}) when not is_nil(date) do
    if date == socket.assigns[:last_date_prop] do
      socket
    else
      socket
      |> assign(:internal_date, date)
      |> assign(:last_date_prop, date)
    end
  end

  defp maybe_sync_date(socket, _assigns), do: socket

  defp maybe_sync_view(socket, %{view: view}) when not is_nil(view) do
    if view == socket.assigns[:last_view_prop] do
      socket
    else
      socket
      |> assign(:internal_view, view)
      |> assign(:last_view_prop, view)
    end
  end

  defp maybe_sync_view(socket, _assigns), do: socket

  # -- Render --

  @impl true
  def render(assigns) do
    # Compute derived values
    assigns =
      assigns
      |> assign_defaults()
      |> assign_title()
      |> filter_events_by_window()
      |> apply_layers()
      |> filter_events_by_visibility()

    ~H"""
    <div
      id={@id}
      class={[
        "cal-container flex flex-col bg-base-100 text-base-content rounded-lg border border-base-content/15 overflow-hidden shadow-sm",
        assigns[:class] || ""
      ]}
      dir={to_string(assigns[:dir] || :ltr)}
      phx-hook={if(assigns[:enable_hooks], do: "PhoenixLiveCalendarContainer")}
    >
      <Header.header
        :if={assigns[:show_header] != false}
        layout={assigns[:header_layout] || :auto}
        title={@title}
        view={@internal_view}
        views={assigns[:views] || [:month, :week, :day]}
        today_visible={today_visible?(assigns)}
        show_today_button={assigns[:show_today_button] || :auto}
        on_prev={
          %Phoenix.LiveView.JS{}
          |> Phoenix.LiveView.JS.push("lc_navigate", target: @myself, value: %{direction: "prev"})
        }
        on_next={
          %Phoenix.LiveView.JS{}
          |> Phoenix.LiveView.JS.push("lc_navigate", target: @myself, value: %{direction: "next"})
        }
        on_today={%Phoenix.LiveView.JS{} |> Phoenix.LiveView.JS.push("lc_today", target: @myself)}
        on_view_change={
          %Phoenix.LiveView.JS{} |> Phoenix.LiveView.JS.push("lc_view_change", target: @myself)
        }
        translations={assigns[:translations] || %{}}
        dir={assigns[:dir] || :ltr}
        help_label={assigns[:info_label] || "About"}
      >
        <%!-- Optional consumer-provided key/legend, surfaced as the toolbar's
             info (ⓘ) disclosure. The calendar owns the icon; the consumer owns
             the words (it knows what its events/markings mean). --%>
        <:help :if={assigns[:info] not in [nil, []]}>{render_slot(assigns[:info])}</:help>
      </Header.header>

      <%!-- Layer legend: one toggle chip per layer. Hidden layers' events are
           filtered SERVER-side; a layer the viewer may not see should simply
           never be passed in. --%>
      <div
        :if={(assigns[:layers] || []) != [] and assigns[:show_legend] != false}
        class="cal-legend flex flex-wrap items-center gap-1 px-2 py-1.5 sm:px-3 border-b border-base-200"
        role="group"
        aria-label={I18n.label(:layers, assigns[:translations] || %{})}
      >
        <button
          :for={layer <- @layers}
          type="button"
          class={[
            "cal-legend-chip btn btn-xs btn-ghost gap-1.5 font-normal",
            layer_hidden?(assigns, layer) && "cal-legend-chip-hidden opacity-45 line-through"
          ]}
          phx-click="lc_layer_toggle"
          phx-value-layer={to_string(layer.id)}
          phx-target={@myself}
          aria-pressed={to_string(not layer_hidden?(assigns, layer))}
        >
          <span
            :if={layer.color}
            class={[
              "cal-legend-dot w-2.5 h-2.5 rounded-full inline-block",
              PhoenixLiveCalendar.Theme.bg(layer.color)
            ]}
            aria-hidden="true"
          >
          </span>
          {layer.label}
        </button>
      </div>

      <div class="cal-view-container flex-1 overflow-auto">
        <.render_view
          view={@internal_view}
          date={@internal_date}
          events={assigns[:events] || []}
          resources={assigns[:resources] || []}
          selected_date={assigns[:selected_date]}
          today={if Map.has_key?(assigns, :today), do: assigns.today, else: Date.utc_today()}
          week_start={assigns[:week_start] || 1}
          min_time={assigns[:min_time] || ~T[00:00:00]}
          max_time={assigns[:max_time] || ~T[23:59:59]}
          slot_duration={assigns[:slot_duration] || 30}
          slot_height={assigns[:slot_height] || "3rem"}
          max_events={assigns[:max_events] || 3}
          max_multiday={assigns[:max_multiday]}
          show_week_numbers={assigns[:show_week_numbers] || false}
          show_weekends={assigns[:show_weekends] != false}
          fixed_weeks={assigns[:fixed_weeks] != false}
          expand_cells={assigns[:expand_cells] || false}
          respect_hours={assigns[:respect_hours] || false}
          show_now_indicator={assigns[:show_now_indicator] != false}
          show_all_day_row={assigns[:show_all_day_row] != false}
          business_hours={assigns[:business_hours] || []}
          translations={assigns[:translations] || %{}}
          time_format={assigns[:time_format] || :h24}
          dir={assigns[:dir] || :ltr}
          n_days={assigns[:n_days] || 4}
          agenda_days={assigns[:agenda_days] || 30}
          year_columns={assigns[:year_columns] || 3}
          day_markers={assigns[:day_markers] || []}
          id={@id}
          now={assigns[:now]}
          marker_ticker={assigns[:marker_ticker] != false}
          marker_ticker_interval={assigns[:marker_ticker_interval] || 3000}
          slot_width={assigns[:slot_width] || "5rem"}
          resource_width={assigns[:resource_width] || "12rem"}
          event_content={assigns[:event_content] || :auto}
          filter_to_date={assigns[:filter_to_date] != false}
          clamp_to_date={assigns[:clamp_to_date] != false}
          sticky_resource_column={assigns[:sticky_resource_column] != false}
          fit_to_events={assigns[:fit_to_events] || false}
          myself={@myself}
        >
          <:event :let={e} :if={assigns[:event] not in [nil, []]}>{render_slot(@event, e)}</:event>
          <:day_cell :let={d} :if={assigns[:day_cell] not in [nil, []]}>
            {render_slot(@day_cell, d)}
          </:day_cell>
          <:time_label :let={t} :if={assigns[:time_label] not in [nil, []]}>
            {render_slot(@time_label, t)}
          </:time_label>
          <:resource_label :let={r} :if={assigns[:resource_label] not in [nil, []]}>
            {render_slot(@resource_label, r)}
          </:resource_label>
          <:resource_header :let={r} :if={assigns[:resource_header] not in [nil, []]}>
            {render_slot(@resource_header, r)}
          </:resource_header>
          <:day_header :let={d} :if={assigns[:day_header] not in [nil, []]}>
            {render_slot(@day_header, d)}
          </:day_header>
          <:no_events :if={assigns[:no_events] not in [nil, []]}>{render_slot(@no_events)}</:no_events>
        </.render_view>
      </div>
    </div>
    """
  end

  # -- View dispatcher --

  attr :view, :atom, required: true
  attr :date, Date, required: true
  attr :events, :list, required: true
  attr :resources, :list, required: true
  attr :selected_date, :any, required: true
  attr :today, Date, required: true
  attr :week_start, :integer, required: true
  attr :min_time, Time, required: true
  attr :max_time, Time, required: true
  attr :slot_duration, :integer, required: true
  attr :slot_height, :string, required: true
  attr :max_events, :integer, required: true
  attr :max_multiday, :integer, default: nil
  attr :expand_cells, :boolean, default: false
  attr :respect_hours, :boolean, default: false
  attr :fixed_weeks, :boolean, default: true
  attr :show_week_numbers, :boolean, required: true
  attr :show_weekends, :boolean, required: true
  attr :show_now_indicator, :boolean, required: true
  attr :show_all_day_row, :boolean, required: true
  attr :business_hours, :list, required: true
  attr :translations, :map, required: true
  attr :time_format, :atom, required: true
  attr :dir, :atom, required: true
  attr :n_days, :integer, required: true
  attr :agenda_days, :integer, required: true
  attr :year_columns, :integer, required: true
  attr :day_markers, :list, required: true
  attr :id, :string, default: nil
  attr :now, Time, default: nil
  attr :marker_ticker, :boolean, default: true
  attr :marker_ticker_interval, :integer, default: 3000
  attr :slot_width, :string, default: "5rem"
  attr :resource_width, :string, default: "12rem"
  attr :event_content, :atom, default: :auto
  attr :filter_to_date, :boolean, default: true
  attr :clamp_to_date, :boolean, default: true
  attr :sticky_resource_column, :boolean, default: true
  attr :fit_to_events, :boolean, default: false
  attr :myself, :any, required: true

  slot :event
  slot :day_cell
  slot :time_label
  slot :resource_label
  slot :resource_header
  slot :day_header
  slot :no_events

  defp render_view(%{view: :month} = assigns) do
    ~H"""
    <MonthGrid.month_grid
      date={@date}
      events={@events}
      day_markers={@day_markers}
      selected_date={@selected_date}
      today={@today}
      week_start={@week_start}
      max_events={@max_events}
      show_week_numbers={@show_week_numbers}
      show_weekends={@show_weekends}
      fixed_weeks={@fixed_weeks}
      id={@id && "#{@id}-month"}
      max_multiday={assigns[:max_multiday]}
      expand_cells={assigns[:expand_cells] || false}
      respect_hours={assigns[:respect_hours] || false}
      marker_ticker={@marker_ticker}
      marker_ticker_interval={@marker_ticker_interval}
      on_date_click={Phoenix.LiveView.JS.push("lc_date_click", target: @myself)}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      on_more_click={Phoenix.LiveView.JS.push("lc_more_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
      dir={@dir}
    >
      <:event :let={e} :if={@event != []}>{render_slot(@event, e)}</:event>
      <:day_cell :let={d} :if={@day_cell != []}>{render_slot(@day_cell, d)}</:day_cell>
    </MonthGrid.month_grid>
    """
  end

  defp render_view(%{view: :week} = assigns) do
    dates = DateHelpers.week_dates(assigns.date, week_start: assigns.week_start)
    assigns = assign(assigns, :dates, dates)

    ~H"""
    <WeekGrid.week_grid
      id={@id && "#{@id}-week"}
      dates={@dates}
      events={@events}
      selected_date={@selected_date}
      today={@today}
      min_time={@min_time}
      max_time={@max_time}
      slot_duration={@slot_duration}
      slot_height={@slot_height}
      show_now_indicator={@show_now_indicator}
      now={@now}
      show_all_day_row={@show_all_day_row}
      business_hours={@business_hours}
      day_markers={@day_markers}
      event_content={@event_content}
      on_date_click={Phoenix.LiveView.JS.push("lc_date_click", target: @myself)}
      on_time_click={Phoenix.LiveView.JS.push("lc_time_click", target: @myself)}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
      dir={@dir}
    >
      <:event :let={e} :if={@event != []}>{render_slot(@event, e)}</:event>
      <:time_label :let={t} :if={@time_label != []}>{render_slot(@time_label, t)}</:time_label>
    </WeekGrid.week_grid>
    """
  end

  defp render_view(%{view: :day} = assigns) do
    ~H"""
    <DayView.day_view
      id={@id && "#{@id}-day"}
      date={@date}
      events={@events}
      selected_date={@selected_date}
      today={@today}
      min_time={@min_time}
      max_time={@max_time}
      slot_duration={@slot_duration}
      slot_height={@slot_height}
      show_now_indicator={@show_now_indicator}
      now={@now}
      show_all_day_row={@show_all_day_row}
      business_hours={@business_hours}
      day_markers={@day_markers}
      event_content={@event_content}
      on_time_click={Phoenix.LiveView.JS.push("lc_time_click", target: @myself)}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
      dir={@dir}
    >
      <:event :let={e} :if={@event != []}>{render_slot(@event, e)}</:event>
      <:time_label :let={t} :if={@time_label != []}>{render_slot(@time_label, t)}</:time_label>
    </DayView.day_view>
    """
  end

  defp render_view(%{view: {:n_day, _}} = assigns) do
    ~H"""
    <NDayView.n_day_view
      id={@id && "#{@id}-nday"}
      date={@date}
      days={@n_days}
      events={@events}
      selected_date={@selected_date}
      today={@today}
      min_time={@min_time}
      max_time={@max_time}
      slot_duration={@slot_duration}
      slot_height={@slot_height}
      show_now_indicator={@show_now_indicator}
      now={@now}
      show_all_day_row={@show_all_day_row}
      business_hours={@business_hours}
      day_markers={@day_markers}
      event_content={@event_content}
      on_time_click={Phoenix.LiveView.JS.push("lc_time_click", target: @myself)}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
      dir={@dir}
    >
      <:event :let={e} :if={@event != []}>{render_slot(@event, e)}</:event>
      <:time_label :let={t} :if={@time_label != []}>{render_slot(@time_label, t)}</:time_label>
    </NDayView.n_day_view>
    """
  end

  defp render_view(%{view: :year} = assigns) do
    ~H"""
    <YearView.year_view
      year={@date.year}
      events={@events}
      day_markers={@day_markers}
      selected_date={@selected_date}
      today={@today}
      week_start={@week_start}
      columns={@year_columns}
      on_date_click={Phoenix.LiveView.JS.push("lc_date_click", target: @myself)}
      translations={@translations}
    />
    """
  end

  defp render_view(%{view: :agenda} = assigns) do
    ~H"""
    <Agenda.agenda
      date={@date}
      events={@events}
      days={@agenda_days}
      today={@today}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      on_date_click={Phoenix.LiveView.JS.push("lc_date_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
    >
      <:event :let={e} :if={@event != []}>{render_slot(@event, e)}</:event>
      <:day_header :let={d} :if={@day_header != []}>{render_slot(@day_header, d)}</:day_header>
      <:no_events :if={@no_events != []}>{render_slot(@no_events)}</:no_events>
    </Agenda.agenda>
    """
  end

  defp render_view(%{view: :timeline} = assigns) do
    ~H"""
    <Timeline.timeline
      id={@id && "#{@id}-timeline"}
      date={@date}
      resources={@resources}
      events={@events}
      min_time={@min_time}
      max_time={@max_time}
      slot_duration={@slot_duration}
      filter_to_date={@filter_to_date}
      clamp_to_date={@clamp_to_date}
      sticky_resource_column={@sticky_resource_column}
      fit_to_events={@fit_to_events}
      show_now_indicator={@show_now_indicator}
      today={@today}
      now={@now}
      slot_width={@slot_width}
      resource_width={@resource_width}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      on_slot_click={Phoenix.LiveView.JS.push("lc_time_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
      dir={@dir}
    >
      <:event :let={e} :if={@event != []}>{render_slot(@event, e)}</:event>
      <:resource_label :let={r} :if={@resource_label != []}>
        {render_slot(@resource_label, r)}
      </:resource_label>
    </Timeline.timeline>
    """
  end

  defp render_view(%{view: :resource} = assigns) do
    ~H"""
    <ResourceView.resource_view
      id={@id && "#{@id}-resource"}
      date={@date}
      resources={@resources}
      events={@events}
      min_time={@min_time}
      max_time={@max_time}
      slot_duration={@slot_duration}
      slot_height={@slot_height}
      show_now_indicator={@show_now_indicator}
      now={@now}
      on_time_click={Phoenix.LiveView.JS.push("lc_time_click", target: @myself)}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
    >
      <:event :let={e} :if={@event != []}>{render_slot(@event, e)}</:event>
      <:resource_header :let={r} :if={@resource_header != []}>
        {render_slot(@resource_header, r)}
      </:resource_header>
    </ResourceView.resource_view>
    """
  end

  # Fallback for unknown views
  defp render_view(assigns) do
    ~H"""
    <div class="p-4 text-error">Unknown view: {@view}</div>
    """
  end

  # -- Event handlers --
  # All handlers are wrapped defensively — no handler should ever crash the LiveView.

  @impl true
  def handle_event("lc_navigate", %{"direction" => direction}, socket) do
    direction_atom = safe_direction(direction)
    view = socket.assigns.internal_view
    date = socket.assigns.internal_date

    new_date =
      Safe.safe_call(
        fn -> DateHelpers.shift(date, normalize_view(view), direction_atom) end,
        date
      )

    socket =
      socket
      |> assign(:internal_date, new_date)
      |> notify_date_range_change()

    {:noreply, socket}
  end

  def handle_event("lc_today", _params, socket) do
    today = socket.assigns[:today] || Date.utc_today()

    socket =
      socket
      |> assign(:internal_date, today)
      |> notify_date_range_change()

    {:noreply, socket}
  end

  def handle_event("lc_view_change", %{"view" => view_str}, socket) do
    case safe_parse_view(view_str) do
      nil ->
        Logger.warning("[PhoenixLiveCalendar] Invalid view: #{inspect(view_str)}")
        {:noreply, socket}

      view ->
        view = resolve_view(view, socket.assigns)

        socket =
          socket
          |> assign(:internal_view, view)
          |> notify_view_change(view)
          |> notify_date_range_change()

        {:noreply, socket}
    end
  end

  def handle_event("lc_layer_toggle", %{"layer" => id}, socket) when is_binary(id) do
    hidden = socket.assigns[:hidden_layer_ids] || MapSet.new()

    hidden =
      if MapSet.member?(hidden, id),
        do: MapSet.delete(hidden, id),
        else: MapSet.put(hidden, id)

    socket = assign(socket, :hidden_layer_ids, hidden)

    {visible_layers, hidden_layers} =
      Enum.split_with(socket.assigns[:layers] || [], fn layer ->
        not MapSet.member?(hidden, to_string(layer.id))
      end)

    notify_callback(socket, :on_layers_change, %{
      visible: Enum.map(visible_layers, & &1.id),
      hidden: Enum.map(hidden_layers, & &1.id)
    })

    {:noreply, socket}
  end

  def handle_event("lc_date_click", %{"date" => date_str}, socket) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        notify_callback(socket, :on_date_select, date)
        {:noreply, socket}

      _ ->
        Logger.warning("[PhoenixLiveCalendar] Invalid date in lc_date_click: #{inspect(date_str)}")
        {:noreply, socket}
    end
  end

  def handle_event("lc_time_click", params, socket) when is_map(params) do
    with date_str when is_binary(date_str) <- params["date"],
         time_str when is_binary(time_str) <- params["time"],
         {:ok, date} <- Date.from_iso8601(date_str),
         {:ok, time} <- Time.from_iso8601(time_str),
         {:ok, ndt} <- NaiveDateTime.new(date, time) do
      data = %{
        date: date,
        time: time,
        datetime: ndt,
        resource_id: params["resource-id"] || params["resource_id"]
      }

      notify_callback(socket, :on_time_select, data)
      {:noreply, socket}
    else
      _ ->
        Logger.warning("[PhoenixLiveCalendar] Invalid params in lc_time_click: #{inspect(params)}")
        {:noreply, socket}
    end
  end

  def handle_event("lc_event_click", %{"event-id" => event_id}, socket) do
    notify_callback(socket, :on_event_click, event_id)
    {:noreply, socket}
  end

  def handle_event("lc_more_click", %{"date" => date_str}, socket) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        notify_callback(socket, :on_more_click, date)
        {:noreply, socket}

      _ ->
        Logger.warning("[PhoenixLiveCalendar] Invalid date in lc_more_click: #{inspect(date_str)}")
        {:noreply, socket}
    end
  end

  # -- JS Hook events --

  def handle_event("lc_range_select", params, socket) when is_map(params) do
    with date_str when is_binary(date_str) <- params["date"],
         start_str when is_binary(start_str) <- params["start_time"],
         end_str when is_binary(end_str) <- params["end_time"],
         {:ok, date} <- Date.from_iso8601(date_str),
         {:ok, start_time} <- Time.from_iso8601(start_str),
         {:ok, end_time} <- Time.from_iso8601(end_str) do
      notify_callback(socket, :on_range_select, %{
        date: date,
        start_time: start_time,
        end_time: end_time
      })
    else
      _ ->
        Logger.warning(
          "[PhoenixLiveCalendar] Invalid params in lc_range_select: #{inspect(params)}"
        )
    end

    {:noreply, socket}
  end

  def handle_event("lc_event_drop", params, socket) when is_map(params) do
    data = %{
      event_id: params["event_id"],
      new_date: safe_parse_date(params["new_date"]),
      new_time: safe_parse_time(params["new_time"]),
      resource_id: params["resource_id"]
    }

    notify_callback(socket, :on_event_drop, data)
    {:noreply, socket}
  end

  def handle_event("lc_event_resize", params, socket) when is_map(params) do
    data = %{
      event_id: params["event_id"],
      edge: params["edge"],
      new_time: safe_parse_time(params["new_time"])
    }

    notify_callback(socket, :on_event_resize, data)
    {:noreply, socket}
  end

  def handle_event("lc_container_resized", %{"width" => width}, socket)
      when is_number(width) do
    notify_callback(socket, :on_container_resized, %{width: round(width)})
    {:noreply, socket}
  end

  # Catch-all for any unmatched event — log and ignore, never crash
  def handle_event(event_name, params, socket) do
    Logger.warning(
      "[PhoenixLiveCalendar] Unhandled event: #{inspect(event_name)}, params: #{inspect(params)}"
    )

    {:noreply, socket}
  end

  # -- Private helpers --

  # Default minimum visibility thresholds per view.
  # Events with visibility below the threshold are filtered out.
  # Uses multiples of 10 for granularity (e.g., 25 shows in week but not month).
  defp default_min_visibility(:day), do: 10
  defp default_min_visibility(:week), do: 20
  defp default_min_visibility(:month), do: 30
  defp default_min_visibility(:year), do: 40
  defp default_min_visibility({:n_day, _}), do: 20
  defp default_min_visibility(:agenda), do: 10
  defp default_min_visibility(:timeline), do: 10
  defp default_min_visibility(:resource), do: 10
  defp default_min_visibility(_), do: 10

  # `events_mode: :window` trims the parent's event list to those occupying
  # the visible range before any view work — the range-driven scaling model:
  # the parent fetches around `on_date_range_change` and may over-fetch
  # freely; the component renders only the visible slice. The window is the
  # SAME `[start, end)` range the callback reports. `:full` (default) trusts
  # the list as-is — identical to pre-0.3 behavior.
  defp filter_events_by_window(assigns) do
    case assigns[:events_mode] do
      :window ->
        opts = [
          week_start: assigns[:week_start] || 1,
          days: assigns[:agenda_days] || 30
        ]

        {range_start, range_end} =
          DateHelpers.visible_range(
            normalize_view(assigns.internal_view),
            assigns.internal_date,
            opts
          )

        events =
          (assigns[:events] || [])
          |> Enum.filter(&Event.in_range?(&1, range_start, range_end))

        assign(assigns, :events, events)

      _ ->
        assigns
    end
  end

  # Layers: drop events belonging to hidden layers, and let events without
  # their own color inherit the layer's. Events with no layer_id (or one
  # matching no passed layer) always render.
  defp apply_layers(assigns) do
    case assigns[:layers] do
      layers when is_list(layers) and layers != [] ->
        hidden = assigns[:hidden_layer_ids] || MapSet.new()
        by_id = Map.new(layers, &{to_string(&1.id), &1})

        events =
          (assigns[:events] || [])
          |> Enum.reject(fn event ->
            event.layer_id != nil and MapSet.member?(hidden, to_string(event.layer_id))
          end)
          |> Enum.map(&inherit_layer_style(&1, by_id))

        assign(assigns, :events, events)

      _ ->
        assigns
    end
  end

  defp inherit_layer_style(%Event{layer_id: nil} = event, _by_id), do: event

  defp inherit_layer_style(%Event{} = event, by_id) do
    case by_id[to_string(event.layer_id)] do
      nil ->
        event

      layer ->
        %{
          event
          | color: event.color || layer.color,
            text_color: event.text_color || layer.text_color
        }
    end
  end

  defp layer_hidden?(assigns, layer) do
    MapSet.member?(assigns[:hidden_layer_ids] || MapSet.new(), to_string(layer.id))
  end

  defp filter_events_by_visibility(assigns) do
    case assigns[:min_visibility] do
      # Explicit override: use the given value
      val when is_integer(val) ->
        events = assigns[:events] || []
        filtered = do_visibility_filter(events, val)
        assign(assigns, :events, filtered)

      # :auto — use per-view defaults
      :auto ->
        min_vis = default_min_visibility(assigns.internal_view)
        events = assigns[:events] || []
        filtered = do_visibility_filter(events, min_vis)
        assign(assigns, :events, filtered)

      # nil / not set — no filtering, show all events
      _ ->
        assigns
    end
  end

  defp do_visibility_filter(events, min_vis) do
    filter_fn = fn -> Enum.filter(events, fn event -> Event.visible_at?(event, min_vis) end) end

    if Telemetry.should_measure?(length(events)) do
      Telemetry.measure_and_warn(
        :filter,
        %{events: length(events), min_visibility: min_vis},
        filter_fn
      )
    else
      filter_fn.()
    end
  end

  # Profile event data at ingress — runs once per update, measures size and memory
  defp maybe_profile_ingress(assigns, socket) do
    if Map.has_key?(assigns, :events) do
      events = assigns[:events] || []
      view = socket.assigns[:internal_view] || assigns[:view] || :unknown
      {count, bytes} = Telemetry.profile_ingress(events, view)
      Map.put(assigns, :_perf, %{event_count: count, estimated_bytes: bytes})
    else
      assigns
    end
  end

  defp assign_defaults(assigns) do
    assigns
    |> assign_new(:show_header, fn -> true end)
    |> assign_new(:views, fn -> [:month, :week, :day] end)
    |> assign_new(:translations, fn -> %{} end)
    |> assign_new(:dir, fn -> :ltr end)
    |> assign_new(:events, fn -> [] end)
    |> assign_new(:resources, fn -> [] end)
  end

  defp assign_title(assigns) do
    title =
      I18n.format_title(
        assigns.internal_view,
        assigns.internal_date,
        week_start: assigns[:week_start] || 1,
        translations: assigns[:translations] || %{}
      )

    assign(assigns, :title, title)
  end

  defp normalize_view({:n_day, _} = v), do: v
  defp normalize_view(v), do: v

  # The switcher sends "n_day" as a flat string (a tuple isn't attribute-safe);
  # the internal representation carries the day count, so rehydrate it here.
  defp resolve_view(:n_day, assigns), do: {:n_day, assigns[:n_days] || 4}
  defp resolve_view(view, _assigns), do: view

  # Safe direction parsing — only :prev and :next are valid
  defp safe_direction("prev"), do: :prev
  defp safe_direction("next"), do: :next

  defp safe_direction(other) do
    Logger.warning(
      "[PhoenixLiveCalendar] Invalid direction: #{inspect(other)}, defaulting to :next"
    )

    :next
  end

  # Safe view parsing — returns nil for invalid views
  defp safe_parse_view("month"), do: :month
  defp safe_parse_view("week"), do: :week
  defp safe_parse_view("day"), do: :day
  defp safe_parse_view("n_day"), do: :n_day
  defp safe_parse_view("year"), do: :year
  defp safe_parse_view("agenda"), do: :agenda
  defp safe_parse_view("timeline"), do: :timeline
  defp safe_parse_view("resource"), do: :resource
  defp safe_parse_view(_), do: nil

  defp safe_parse_date(nil), do: nil

  defp safe_parse_date(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp safe_parse_date(_), do: nil

  defp safe_parse_time(nil), do: nil

  defp safe_parse_time(str) when is_binary(str) do
    case Time.from_iso8601(str) do
      {:ok, time} -> time
      _ -> nil
    end
  end

  defp safe_parse_time(_), do: nil

  defp notify_callback(socket, callback_key, data) do
    case Map.get(socket.assigns, callback_key) do
      nil ->
        :ok

      callback when is_function(callback) ->
        try do
          callback.(data)
        rescue
          e ->
            Logger.warning(
              "[PhoenixLiveCalendar] Callback #{callback_key} raised: #{Exception.message(e)}"
            )
        end

      other ->
        Logger.warning(
          "[PhoenixLiveCalendar] Expected function for #{callback_key}, got: #{inspect(other)}"
        )
    end
  end

  defp today_visible?(assigns) do
    today = if Map.has_key?(assigns, :today), do: assigns.today, else: Date.utc_today()

    if today do
      view = assigns.internal_view
      date = assigns.internal_date
      opts = [week_start: assigns[:week_start] || 1]
      {range_start, range_end} = DateHelpers.visible_range(normalize_view(view), date, opts)
      Date.compare(today, range_start) != :lt and Date.compare(today, range_end) == :lt
    else
      false
    end
  end

  defp notify_view_change(socket, view) do
    notify_callback(socket, :on_view_change, %{
      view: view,
      date: socket.assigns.internal_date
    })

    socket
  end

  defp notify_date_range_change(socket) do
    view = socket.assigns.internal_view
    date = socket.assigns.internal_date

    opts = [
      week_start: Map.get(socket.assigns, :week_start, 1),
      days: Map.get(socket.assigns, :agenda_days) || 30
    ]

    {start_date, end_date} = DateHelpers.visible_range(normalize_view(view), date, opts)

    notify_callback(socket, :on_date_range_change, %{
      start: start_date,
      end: end_date,
      view: view,
      date: date
    })

    socket
  end
end
