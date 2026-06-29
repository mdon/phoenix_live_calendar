defmodule PhoenixLiveCalendar.Store.Ecto.EventSchemaTest do
  use ExUnit.Case, async: true

  # The schema module only compiles when Ecto is available (an optional dep).
  # It is present in this lib's own test env, so these pure changeset/mapping
  # tests run without a database.
  alias PhoenixLiveCalendar.Store.Ecto.EventSchema

  describe "changeset/2" do
    test "is valid with a start_at" do
      cs = EventSchema.changeset(%{start_at: ~U[2026-04-01 09:00:00Z], title: "X"})
      assert cs.valid?
    end

    test "requires start_at" do
      cs = EventSchema.changeset(%{title: "X"})
      refute cs.valid?
      assert cs.errors[:start_at]
    end

    test "rejects an end_at that is not after start_at" do
      cs =
        EventSchema.changeset(%{
          start_at: ~U[2026-04-01 10:00:00Z],
          end_at: ~U[2026-04-01 09:00:00Z]
        })

      refute cs.valid?
      assert cs.errors[:end_at]
    end

    test "validates the status inclusion list" do
      cs = EventSchema.changeset(%{start_at: ~U[2026-04-01 09:00:00Z], status: "bogus"})
      refute cs.valid?
      assert cs.errors[:status]
    end

    test "accepts a known status" do
      cs = EventSchema.changeset(%{start_at: ~U[2026-04-01 09:00:00Z], status: "tentative"})
      assert cs.valid?
    end

    test "accepts the full set of Event statuses" do
      for s <- ["confirmed", "tentative", "cancelled", "pending_approval", "no_show"] do
        assert EventSchema.changeset(%{start_at: ~U[2026-04-01 09:00:00Z], status: s}).valid?,
               "expected status #{s} to be valid"
      end
    end

    test "validates priority and urgency inclusion" do
      base = %{start_at: ~U[2026-04-01 09:00:00Z]}
      refute EventSchema.changeset(Map.put(base, :priority, "bogus")).valid?
      refute EventSchema.changeset(Map.put(base, :urgency, "bogus")).valid?
      assert EventSchema.changeset(Map.merge(base, %{priority: "high", urgency: "critical"})).valid?
    end
  end

  describe "to_event/1" do
    test "maps a timed schema to a PhoenixLiveCalendar.Event" do
      schema = %EventSchema{
        id: "e",
        title: "T",
        start_at: ~U[2026-04-01 09:00:00Z],
        end_at: ~U[2026-04-01 10:00:00Z],
        all_day: false,
        status: "tentative",
        display: "background"
      }

      event = EventSchema.to_event(schema)

      assert event.__struct__ == PhoenixLiveCalendar.Event
      assert event.id == "e"
      assert event.start == ~U[2026-04-01 09:00:00Z]
      assert event.end == ~U[2026-04-01 10:00:00Z]
      assert event.status == :tentative
      assert event.display == :background
    end

    test "round-trips the full Event field set" do
      schema = %EventSchema{
        id: "e",
        title: "T",
        start_at: ~U[2026-04-01 09:00:00Z],
        end_at: ~U[2026-04-01 10:00:00Z],
        all_day: false,
        class: "ring-2",
        resource_ids: ["r1", "r2"],
        icon: "hero-bell",
        badge: "NEW",
        border_color: "border-red-500",
        visibility: 40,
        status: "no_show",
        priority: "high",
        urgency: "critical"
      }

      event = EventSchema.to_event(schema)

      assert event.class == "ring-2"
      assert event.resource_ids == ["r1", "r2"]
      assert event.icon == "hero-bell"
      assert event.badge == "NEW"
      assert event.border_color == "border-red-500"
      assert event.visibility == 40
      assert event.status == :no_show
      assert event.priority == :high
      assert event.urgency == :critical
    end

    test "maps every status / priority / urgency string to its atom" do
      base = %EventSchema{id: "s", start_at: ~U[2026-04-01 09:00:00Z]}

      for {str, atom} <- %{
            "confirmed" => :confirmed,
            "tentative" => :tentative,
            "cancelled" => :cancelled,
            "pending_approval" => :pending_approval,
            "no_show" => :no_show
          } do
        assert EventSchema.to_event(%{base | status: str}).status == atom
      end

      for {str, atom} <- %{"low" => :low, "normal" => :normal, "high" => :high, "urgent" => :urgent} do
        assert EventSchema.to_event(%{base | priority: str}).priority == atom
      end

      for {str, atom} <- %{
            "none" => :none,
            "attention" => :attention,
            "warning" => :warning,
            "critical" => :critical
          } do
        assert EventSchema.to_event(%{base | urgency: str}).urgency == atom
      end
    end

    test "visibility/priority/urgency fall back to model defaults when nil" do
      schema = %EventSchema{
        id: "x",
        start_at: ~U[2026-04-01 09:00:00Z],
        visibility: nil,
        priority: nil,
        urgency: nil
      }

      event = EventSchema.to_event(schema)

      assert event.visibility == 20
      assert event.priority == :normal
      assert event.urgency == :none
    end

    test "maps an all-day schema using its date fields" do
      schema = %EventSchema{
        id: "a",
        all_day: true,
        start_at: ~U[2026-04-01 00:00:00Z],
        start_date: ~D[2026-04-01],
        end_date: ~D[2026-04-03]
      }

      event = EventSchema.to_event(schema)

      assert event.all_day
      assert event.start == ~D[2026-04-01]
      assert event.end == ~D[2026-04-03]
    end

    test "derives the date from start_at when start_date is absent on an all-day event" do
      schema = %EventSchema{id: "a", all_day: true, start_at: ~U[2026-04-01 12:00:00Z]}
      assert EventSchema.to_event(schema).start == ~D[2026-04-01]
    end

    test "unknown status/display strings fall back to safe defaults" do
      schema = %EventSchema{id: "x", start_at: ~U[2026-04-01 09:00:00Z], status: nil, display: nil}
      event = EventSchema.to_event(schema)

      assert event.status == :confirmed
      assert event.display == :auto
    end
  end
end
