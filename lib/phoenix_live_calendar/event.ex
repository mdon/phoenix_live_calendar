defmodule PhoenixLiveCalendar.Event do
  @moduledoc """
  Represents a calendar event.

  Consumers map their database records to this struct before passing them

  to calendar components. Only `id` and `start` are required — everything
  else has sensible defaults.

  ## End time semantics

  End times are **exclusive** (half-open interval `[start, end)`).

  - An all-day event on April 1st: `start: ~D[2026-04-01], end: ~D[2026-04-02]`
  - A 1-hour meeting at 10am: `start: ~U[2026-04-01 10:00:00Z], end: ~U[2026-04-01 11:00:00Z]`

  If `end` is `nil`, a default duration is applied:
  - All-day events default to 1 day
  - Timed events default to 30 minutes

  ## Examples

      # Minimal event
      %PhoenixLiveCalendar.Event{id: "1", start: ~D[2026-04-01]}

      # Timed event with details
      %PhoenixLiveCalendar.Event{
        id: "meeting-1",
        title: "Team Standup",
        start: ~U[2026-04-01 09:00:00Z],
        end: ~U[2026-04-01 09:30:00Z],
        color: "bg-primary"
      }

      # All-day event spanning multiple days
      %PhoenixLiveCalendar.Event{
        id: "vacation-1",
        title: "Spring Break",
        start: ~D[2026-04-06],
        end: ~D[2026-04-11],
        all_day: true
      }

      # Booking with resource and constraints
      %PhoenixLiveCalendar.Event{
        id: "booking-1",
        title: "Dr. Smith - Consultation",
        start: ~U[2026-04-01 14:00:00Z],
        end: ~U[2026-04-01 15:00:00Z],
        resource_id: "room-a",
        editable: false,
        overlap: false,
        extra: %{patient_id: "p-123", type: :consultation}
      }

  ## Visibility tiers

  The `visibility` field controls which views an event appears in.
  Higher values mean the event appears in more zoomed-out views.
  Uses multiples of 10 for granularity between tiers.

  | Visibility | Shows in                          | Example use          |
  |-----------|-----------------------------------|----------------------|
  | 10        | Day only                          | Lunch breaks, focus time |
  | 20        | Day + Week (default)              | Regular meetings     |
  | 25        | Day + Week                        | Slightly important   |
  | 30        | Day + Week + Month                | Key deadlines        |
  | 35        | Day + Week + Month                | High priority        |
  | 40        | Day + Week + Month + Year         | Company milestones   |

  The CalendarComponent applies view-specific thresholds automatically.
  Override with `min_visibility` attribute on the component.
  """

  require Logger

  @enforce_keys [:id, :start]
  defstruct [
    # Identity
    :id,

    # Content
    :title,
    :description,
    :location,
    :url,

    # Timing
    :start,
    :end,

    # Display
    :color,
    :text_color,
    :class,

    # Grouping
    :group_id,
    :resource_id,
    :resource_ids,
    :category,

    # Recurrence
    :rrule,
    :recurrence_id,

    # Visual hints (optional — used for conditional rendering)
    :icon,
    :badge,
    :border_color,

    # Fields with defaults (must come after bare fields)
    visibility: 20,
    all_day: false,
    display: :auto,
    editable: true,
    overlap: true,
    status: :confirmed,
    transparency: :opaque,
    priority: :normal,
    urgency: :none,
    extra: %{}
  ]

  @type display :: :auto | :background | :inverse_background | :none
  @type status :: :confirmed | :tentative | :cancelled | :pending_approval | :no_show
  @type transparency :: :opaque | :transparent
  @type priority :: :low | :normal | :high | :urgent
  @type urgency :: :none | :attention | :warning | :critical

  @type t :: %__MODULE__{
          id: term(),
          title: String.t() | nil,
          description: String.t() | nil,
          location: String.t() | nil,
          url: String.t() | nil,
          start: Date.t() | DateTime.t() | NaiveDateTime.t(),
          end: Date.t() | DateTime.t() | NaiveDateTime.t() | nil,
          visibility: pos_integer(),
          all_day: boolean(),
          color: String.t() | nil,
          text_color: String.t() | nil,
          class: String.t() | nil,
          display: display(),
          group_id: term() | nil,
          resource_id: term() | nil,
          resource_ids: [term()] | nil,
          category: String.t() | atom() | nil,
          editable: boolean(),
          overlap: boolean(),
          status: status(),
          transparency: transparency(),
          priority: priority(),
          urgency: urgency(),
          rrule: String.t() | nil,
          recurrence_id: term() | nil,
          icon: String.t() | nil,
          badge: String.t() | nil,
          border_color: String.t() | nil,
          extra: map()
        }

  @doc """
  Returns whether this event meets a minimum visibility threshold.

  Events with `visibility >= min_visibility` are considered visible.
  Default event visibility is 20 (shows in day and week views).

  ## View defaults

  | View     | Threshold | Shows events with visibility >= |
  |----------|-----------|-------------------------------|
  | Day      | 10        | 10+ (almost everything)       |
  | Week     | 20        | 20+ (default events)          |
  | Month    | 30        | 30+ (important only)          |
  | Year     | 40        | 40+ (highest importance)      |

  ## Examples

      iex> Event.visible_at?(%Event{id: 1, start: ~D[2026-04-01], visibility: 20}, 30)
      false

      iex> Event.visible_at?(%Event{id: 1, start: ~D[2026-04-01], visibility: 30}, 30)
      true
  """
  @spec visible_at?(t(), pos_integer()) :: boolean()
  def visible_at?(%__MODULE__{visibility: vis}, min_visibility), do: vis >= min_visibility

  @doc """
  Returns whether this event is an all-day event.

  An event is considered all-day if `all_day` is `true` or if
  `start` is a `Date` (not a `DateTime` or `NaiveDateTime`).
  """
  @spec all_day?(t()) :: boolean()
  def all_day?(%__MODULE__{all_day: true}), do: true
  def all_day?(%__MODULE__{start: %Date{}}), do: true
  def all_day?(%__MODULE__{}), do: false

  @doc """
  Returns the effective end time/date for this event.

  If `end` is nil, applies a default duration:
  - All-day events: start + 1 day
  - Timed events: start + 30 minutes
  """
  @spec effective_end(t()) :: Date.t() | DateTime.t() | NaiveDateTime.t()
  def effective_end(%__MODULE__{end: end_time}) when not is_nil(end_time), do: end_time

  def effective_end(%__MODULE__{start: %Date{} = start}),
    do: Date.add(start, 1)

  def effective_end(%__MODULE__{start: %DateTime{} = start}),
    do: DateTime.add(start, 30 * 60, :second)

  def effective_end(%__MODULE__{start: %NaiveDateTime{} = start}),
    do: NaiveDateTime.add(start, 30 * 60, :second)

  @doc """
  Returns the duration of the event in seconds.

  For all-day events, returns the number of days multiplied by 86400.
  """
  @spec duration_seconds(t()) :: integer()
  def duration_seconds(%__MODULE__{} = event) do
    start = event.start
    end_time = effective_end(event)

    case {start, end_time} do
      {%Date{} = s, %Date{} = e} ->
        Date.diff(e, s) * 86_400

      {%DateTime{} = s, %DateTime{} = e} ->
        DateTime.diff(e, s, :second)

      {%NaiveDateTime{} = s, %NaiveDateTime{} = e} ->
        NaiveDateTime.diff(e, s, :second)

      _ ->
        # Mismatched types — convert both to date and return days in seconds
        Logger.warning(
          "[PhoenixLiveCalendar] Mismatched date types in duration_seconds for event #{inspect(event.id)}"
        )

        Date.diff(to_date(end_time), to_date(start)) * 86_400
    end
  end

  @doc """
  Returns whether this event spans multiple days.
  """
  @spec multi_day?(t()) :: boolean()
  def multi_day?(%__MODULE__{} = event) do
    start_date = to_date(event.start)
    end_date = to_date(effective_end(event))
    Date.diff(end_date, start_date) > 1
  end

  @doc """
  Returns whether this event occupies more than one calendar DATE — i.e. its
  first and last occupied days differ.

  This is the right test for "render as one continuous bar across day cells"
  on a date grid: it is true for a multi-day all-day event AND for a timed
  event that runs past midnight into another date (a 10pm→2am event is on two
  dates), but false for a same-day event or one that ends exactly at midnight
  (which occupies only the starting day). Unlike `multi_day?/1`, it doesn't
  care how many hours the event lasts — only which dates it touches.
  """
  @spec spans_multiple_dates?(t()) :: boolean()
  def spans_multiple_dates?(%__MODULE__{} = event) do
    Date.compare(last_date(event), to_date(event.start)) == :gt
  end

  @doc """
  Returns whether this event overlaps with the given date range `[range_start, range_end)`.
  """
  @spec overlaps_range?(t(), Date.t() | DateTime.t(), Date.t() | DateTime.t()) :: boolean()
  def overlaps_range?(%__MODULE__{} = event, range_start, range_end) do
    event_start = event.start
    event_end = effective_end(event)

    compare(event_start, range_end) == :lt and compare(event_end, range_start) == :gt
  end

  @doc """
  Returns whether this event falls on the given date.
  """
  @spec on_date?(t(), Date.t()) :: boolean()
  def on_date?(%__MODULE__{} = event, %Date{} = date) do
    Date.compare(to_date(event.start), date) != :gt and
      Date.compare(last_date(event), date) != :lt
  end

  @doc """
  The LAST calendar date this event occupies on a date grid (inclusive).

  This is the single source of truth for "which day is the event's last
  day", so bar rendering and occupancy never disagree:

  - All-day events: `end` is exclusive, so the last day is `end - 1`.
  - Timed events: the event occupies the date it ends ON (an event ending
    10:30 on the 17th is on the 17th) — UNLESS it ends exactly at midnight
    (00:00:00), the boundary, which does not count as occupying that day.
  """
  @spec last_date(t()) :: Date.t()
  def last_date(%__MODULE__{} = event) do
    event_end = to_date(effective_end(event))

    cond do
      all_day?(event) -> Date.add(event_end, -1)
      end_time_of(effective_end(event)) == ~T[00:00:00] -> Date.add(event_end, -1)
      true -> event_end
    end
  end

  @doc """
  The FIRST calendar date this event occupies (its start date).
  """
  @spec first_date(t()) :: Date.t()
  def first_date(%__MODULE__{} = event), do: to_date(event.start)

  @doc """
  Whether the event occupies any date in `[range_start, range_end)` —
  inclusive start, EXCLUSIVE end, the same shape `on_date_range_change`
  reports and `DateHelpers.visible_range/3` returns.

  Uses the same occupancy rule as `on_date?/2`/`last_date/1`, so a timed
  event running past midnight counts on its spill-over day and an event
  ending exactly at midnight does not.
  """
  @spec in_range?(t(), Date.t(), Date.t()) :: boolean()
  def in_range?(%__MODULE__{} = event, %Date{} = range_start, %Date{} = range_end) do
    Date.compare(last_date(event), range_start) != :lt and
      Date.compare(first_date(event), range_end) == :lt
  end

  # Compare two date/datetime values regardless of type
  defp compare(%Date{} = a, %Date{} = b), do: Date.compare(a, b)
  defp compare(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b)
  defp compare(%NaiveDateTime{} = a, %NaiveDateTime{} = b), do: NaiveDateTime.compare(a, b)
  defp compare(a, b), do: Date.compare(to_date(a), to_date(b))

  defp to_date(%Date{} = d), do: d
  defp to_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp to_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt)

  defp end_time_of(%DateTime{} = dt), do: DateTime.to_time(dt)
  defp end_time_of(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_time(ndt)
  defp end_time_of(%Date{}), do: nil
end
