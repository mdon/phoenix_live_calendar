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
    event_start = to_date(event.start)
    event_end = to_date(effective_end(event))

    # For timed events (not all-day), the end date needs special handling:
    # A timed event ending at 10:30 on April 1 still occupies April 1.
    # Only all-day events use exclusive end dates at the date level.
    # For timed events, if end is on the same date as start, it occupies that date.
    effective_end_date =
      if all_day?(event) do
        event_end
      else
        # Timed event: add 1 day for comparison because the event occupies
        # at least part of that day. UNLESS the end time is exactly midnight
        # (00:00:00), which means the event ended at the boundary and should
        # NOT count as occupying the next day.
        end_time = end_time_of(effective_end(event))

        if end_time != nil and end_time == ~T[00:00:00] do
          event_end
        else
          Date.add(event_end, 1)
        end
      end

    Date.compare(event_start, date) != :gt and Date.compare(effective_end_date, date) == :gt
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
