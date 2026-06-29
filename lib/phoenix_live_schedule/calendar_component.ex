defmodule PhoenixLiveSchedule.CalendarComponent do
  @moduledoc """
  The main calendar LiveComponent.

  Manages internal state (current date, view mode, navigation) and renders
  the appropriate view. Communicates with the parent via callback functions.

  ## Usage

      <.live_component
        module={PhoenixLiveSchedule.CalendarComponent}
        id="my-calendar"
        events={@events}
        on_date_select={fn date -> send(self(), {:date_selected, date}) end}
        on_event_click={fn event_id -> send(self(), {:event_clicked, event_id}) end}
      />

  ## Full example with all options

      <.live_component
        module={PhoenixLiveSchedule.CalendarComponent}
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
  """

  use Phoenix.LiveComponent

  require Logger

  # Compile-time check: warn if CSS integration hasn't been installed
  unless Application.compile_env(:phoenix_live_schedule, :skip_install_check, false) do
    unless PhoenixLiveSchedule.installed?() do
      IO.warn("""
      PhoenixLiveSchedule CSS integration not detected.

      Tailwind will not scan PhoenixLiveSchedule's component templates, so styles
      (including rounded corners, colors, and layout) will be missing.

      Run:  mix phoenix_live_schedule.install

      To suppress this warning, add to your config:

          config :phoenix_live_schedule, skip_install_check: true
      """)
    end
  end

  alias PhoenixLiveSchedule.Event
  alias PhoenixLiveSchedule.Utils.{DateHelpers, I18n, Safe, Telemetry}

  alias PhoenixLiveSchedule.Views.{
    Agenda,
    DayView,
    MonthGrid,
    NDayView,
    ResourceView,
    Timeline,
    WeekGrid,
    YearView
  }

  alias PhoenixLiveSchedule.Components.Header

  # -- Mount --

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign_new(:internal_date, fn -> Date.utc_today() end)
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

    # On first render or when parent pushes a new date/view, sync internal state
    socket =
      socket
      |> assign(assigns)
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
      |> filter_events_by_visibility()

    ~H"""
    <div
      id={@id}
      class={[
        "cal-container flex flex-col bg-base-100 text-base-content rounded-lg border border-base-content/15 overflow-hidden shadow-sm",
        assigns[:class] || ""
      ]}
      dir={to_string(assigns[:dir] || :ltr)}
      phx-hook={if(assigns[:enable_hooks], do: "PhoenixLiveScheduleContainer")}
    >
      <Header.header
        :if={assigns[:show_header] != false}
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
          myself={@myself}
        />
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
  attr :myself, :any, required: true

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
      max_multiday={assigns[:max_multiday]}
      expand_cells={assigns[:expand_cells] || false}
      marker_ticker={assigns[:marker_ticker] != false}
      marker_ticker_interval={assigns[:marker_ticker_interval] || 3000}
      on_date_click={Phoenix.LiveView.JS.push("lc_date_click", target: @myself)}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      on_more_click={Phoenix.LiveView.JS.push("lc_more_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
      dir={@dir}
    />
    """
  end

  defp render_view(%{view: :week} = assigns) do
    dates = DateHelpers.week_dates(assigns.date, week_start: assigns.week_start)
    assigns = assign(assigns, :dates, dates)

    ~H"""
    <WeekGrid.week_grid
      dates={@dates}
      events={@events}
      selected_date={@selected_date}
      today={@today}
      min_time={@min_time}
      max_time={@max_time}
      slot_duration={@slot_duration}
      slot_height={@slot_height}
      show_now_indicator={@show_now_indicator}
      show_all_day_row={@show_all_day_row}
      business_hours={@business_hours}
      on_date_click={Phoenix.LiveView.JS.push("lc_date_click", target: @myself)}
      on_time_click={Phoenix.LiveView.JS.push("lc_time_click", target: @myself)}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
      dir={@dir}
    />
    """
  end

  defp render_view(%{view: :day} = assigns) do
    ~H"""
    <DayView.day_view
      date={@date}
      events={@events}
      selected_date={@selected_date}
      today={@today}
      min_time={@min_time}
      max_time={@max_time}
      slot_duration={@slot_duration}
      slot_height={@slot_height}
      show_now_indicator={@show_now_indicator}
      show_all_day_row={@show_all_day_row}
      business_hours={@business_hours}
      on_time_click={Phoenix.LiveView.JS.push("lc_time_click", target: @myself)}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
      dir={@dir}
    />
    """
  end

  defp render_view(%{view: {:n_day, _}} = assigns) do
    ~H"""
    <NDayView.n_day_view
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
      show_all_day_row={@show_all_day_row}
      business_hours={@business_hours}
      on_time_click={Phoenix.LiveView.JS.push("lc_time_click", target: @myself)}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
      dir={@dir}
    />
    """
  end

  defp render_view(%{view: :year} = assigns) do
    ~H"""
    <YearView.year_view
      year={@date.year}
      events={@events}
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
    />
    """
  end

  defp render_view(%{view: :timeline} = assigns) do
    ~H"""
    <Timeline.timeline
      date={@date}
      resources={@resources}
      events={@events}
      min_time={@min_time}
      max_time={@max_time}
      slot_duration={@slot_duration}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      on_slot_click={Phoenix.LiveView.JS.push("lc_time_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
      dir={@dir}
    />
    """
  end

  defp render_view(%{view: :resource} = assigns) do
    ~H"""
    <ResourceView.resource_view
      date={@date}
      resources={@resources}
      events={@events}
      min_time={@min_time}
      max_time={@max_time}
      slot_duration={@slot_duration}
      slot_height={@slot_height}
      show_now_indicator={@show_now_indicator}
      on_time_click={Phoenix.LiveView.JS.push("lc_time_click", target: @myself)}
      on_event_click={Phoenix.LiveView.JS.push("lc_event_click", target: @myself)}
      translations={@translations}
      time_format={@time_format}
    />
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
        Logger.warning("[PhoenixLiveSchedule] Invalid view: #{inspect(view_str)}")
        {:noreply, socket}

      view ->
        socket =
          socket
          |> assign(:internal_view, view)
          |> notify_view_change(view)
          |> notify_date_range_change()

        {:noreply, socket}
    end
  end

  def handle_event("lc_date_click", %{"date" => date_str}, socket) when is_binary(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} ->
        notify_callback(socket, :on_date_select, date)
        {:noreply, socket}

      _ ->
        Logger.warning("[PhoenixLiveSchedule] Invalid date in lc_date_click: #{inspect(date_str)}")
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
        Logger.warning("[PhoenixLiveSchedule] Invalid params in lc_time_click: #{inspect(params)}")
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
        Logger.warning("[PhoenixLiveSchedule] Invalid date in lc_more_click: #{inspect(date_str)}")
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
          "[PhoenixLiveSchedule] Invalid params in lc_range_select: #{inspect(params)}"
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
      "[PhoenixLiveSchedule] Unhandled event: #{inspect(event_name)}, params: #{inspect(params)}"
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

  # Safe direction parsing — only :prev and :next are valid
  defp safe_direction("prev"), do: :prev
  defp safe_direction("next"), do: :next

  defp safe_direction(other) do
    Logger.warning(
      "[PhoenixLiveSchedule] Invalid direction: #{inspect(other)}, defaulting to :next"
    )

    :next
  end

  # Safe view parsing — returns nil for invalid views
  defp safe_parse_view("month"), do: :month
  defp safe_parse_view("week"), do: :week
  defp safe_parse_view("day"), do: :day
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
              "[PhoenixLiveSchedule] Callback #{callback_key} raised: #{Exception.message(e)}"
            )
        end

      other ->
        Logger.warning(
          "[PhoenixLiveSchedule] Expected function for #{callback_key}, got: #{inspect(other)}"
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
    opts = [week_start: Map.get(socket.assigns, :week_start, 1)]

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
