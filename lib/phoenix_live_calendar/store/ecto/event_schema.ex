if Code.ensure_loaded?(Ecto) do
  defmodule PhoenixLiveCalendar.Store.Ecto.EventSchema do
    @moduledoc """
    Default Ecto schema for calendar events.

    This schema is provided as a convenience for consumers who opt into
    the Ecto persistence layer. It maps directly to `PhoenixLiveCalendar.Event`.

    ## Table name

    Defaults to `phoenix_live_calendar_events`. Configure with:

        config :phoenix_live_calendar, table_prefix: "my_prefix"

    ## Primary key

    Uses UUID by default. Compatible with UUIDv7 when available.
    """

    use Ecto.Schema
    import Ecto.Changeset

    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id

    @typedoc "Persisted calendar-event row (the runtime struct is `PhoenixLiveCalendar.Event`)."
    @type t :: %__MODULE__{}

    schema "phoenix_live_calendar_events" do
      field(:title, :string)
      field(:description, :string)
      field(:location, :string)
      field(:url, :string)

      field(:start_at, :utc_datetime)
      field(:end_at, :utc_datetime)
      field(:all_day, :boolean, default: false)
      field(:start_date, :date)
      field(:end_date, :date)

      field(:color, :string)
      field(:text_color, :string)
      field(:class, :string)

      field(:group_id, :string)
      field(:resource_id, :string)
      field(:resource_ids, {:array, :string})
      field(:category, :string)

      field(:editable, :boolean, default: true)
      field(:overlap, :boolean, default: true)
      field(:display, :string, default: "auto")

      field(:status, :string, default: "confirmed")
      field(:transparency, :string, default: "opaque")
      field(:priority, :string, default: "normal")
      field(:urgency, :string, default: "none")
      field(:visibility, :integer, default: 20)

      field(:icon, :string)
      field(:badge, :string)
      field(:border_color, :string)

      field(:rrule, :string)
      field(:recurrence_id, :binary_id)

      field(:calendar_id, :string)
      field(:extra, :map, default: %{})

      timestamps(type: :utc_datetime)
    end

    @required_fields [:start_at]
    @optional_fields [
      :title,
      :description,
      :location,
      :url,
      :end_at,
      :all_day,
      :start_date,
      :end_date,
      :color,
      :text_color,
      :class,
      :group_id,
      :resource_id,
      :resource_ids,
      :category,
      :editable,
      :overlap,
      :display,
      :status,
      :transparency,
      :priority,
      :urgency,
      :visibility,
      :icon,
      :badge,
      :border_color,
      :rrule,
      :recurrence_id,
      :calendar_id,
      :extra
    ]

    @doc "Creates a changeset for a new event."
    def changeset(event \\ %__MODULE__{}, attrs) do
      event
      |> cast(attrs, @required_fields ++ @optional_fields)
      |> validate_required(@required_fields)
      |> validate_inclusion(:status, [
        "confirmed",
        "tentative",
        "cancelled",
        "pending_approval",
        "no_show"
      ])
      |> validate_inclusion(:transparency, ["opaque", "transparent"])
      |> validate_inclusion(:display, ["auto", "background", "inverse_background", "none"])
      |> validate_inclusion(:priority, ["low", "normal", "high", "urgent"])
      |> validate_inclusion(:urgency, ["none", "attention", "warning", "critical"])
      |> validate_time_order()
    end

    @doc "Converts this Ecto schema to a `PhoenixLiveCalendar.Event` struct."
    def to_event(%__MODULE__{} = schema) do
      {start, end_val} =
        if schema.all_day do
          {schema.start_date || DateTime.to_date(schema.start_at),
           schema.end_date || (schema.end_at && DateTime.to_date(schema.end_at))}
        else
          {schema.start_at, schema.end_at}
        end

      %PhoenixLiveCalendar.Event{
        id: schema.id,
        title: schema.title,
        description: schema.description,
        location: schema.location,
        url: schema.url,
        start: start,
        end: end_val,
        all_day: schema.all_day || false,
        color: schema.color,
        text_color: schema.text_color,
        class: schema.class,
        display: parse_display(schema.display),
        group_id: schema.group_id,
        resource_id: schema.resource_id,
        resource_ids: schema.resource_ids,
        category: schema.category,
        editable: schema.editable,
        overlap: schema.overlap,
        status: parse_status(schema.status),
        transparency: parse_transparency(schema.transparency),
        priority: parse_priority(schema.priority),
        urgency: parse_urgency(schema.urgency),
        visibility: schema.visibility || 20,
        icon: schema.icon,
        badge: schema.badge,
        border_color: schema.border_color,
        rrule: schema.rrule,
        recurrence_id: schema.recurrence_id,
        extra: schema.extra || %{}
      }
    end

    defp validate_time_order(changeset) do
      start_at = get_field(changeset, :start_at)
      end_at = get_field(changeset, :end_at)

      if start_at && end_at && DateTime.compare(start_at, end_at) != :lt do
        add_error(changeset, :end_at, "must be after start time")
      else
        changeset
      end
    end

    defp parse_display("auto"), do: :auto
    defp parse_display("background"), do: :background
    defp parse_display("inverse_background"), do: :inverse_background
    defp parse_display("none"), do: :none
    defp parse_display(_), do: :auto

    defp parse_status("confirmed"), do: :confirmed
    defp parse_status("tentative"), do: :tentative
    defp parse_status("cancelled"), do: :cancelled
    defp parse_status("pending_approval"), do: :pending_approval
    defp parse_status("no_show"), do: :no_show
    defp parse_status(_), do: :confirmed

    defp parse_transparency("opaque"), do: :opaque
    defp parse_transparency("transparent"), do: :transparent
    defp parse_transparency(_), do: :opaque

    defp parse_priority("low"), do: :low
    defp parse_priority("normal"), do: :normal
    defp parse_priority("high"), do: :high
    defp parse_priority("urgent"), do: :urgent
    defp parse_priority(_), do: :normal

    defp parse_urgency("none"), do: :none
    defp parse_urgency("attention"), do: :attention
    defp parse_urgency("warning"), do: :warning
    defp parse_urgency("critical"), do: :critical
    defp parse_urgency(_), do: :none
  end
end
