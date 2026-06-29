defmodule EventStoreEctoFakeRepo do
  @moduledoc false
  # A repo stand-in: returns the schema stashed in the process dict, so the store
  # logic (query building, changeset, to_event mapping, delegation) is exercised
  # without a real database.
  alias PhoenixLiveCalendar.Store.Ecto.EventSchema

  def all(query, _opts) do
    Process.put(:captured_query, query)
    [Process.get(:fake_schema)]
  end

  def get(_queryable, id, _opts),
    do: if(id == "e1", do: Process.get(:fake_schema), else: nil)

  def insert(%Ecto.Changeset{} = cs, _opts), do: result(cs)
  def update(%Ecto.Changeset{} = cs, _opts), do: result(cs)
  def delete(%EventSchema{} = schema, _opts), do: {:ok, schema}

  defp result(%Ecto.Changeset{valid?: true} = cs), do: {:ok, Ecto.Changeset.apply_changes(cs)}
  defp result(%Ecto.Changeset{} = cs), do: {:error, %{cs | action: :insert}}
end

defmodule PhoenixLiveCalendar.Store.Ecto.EventStoreEctoTest do
  # async: false — mutates the global :phoenix_live_calendar, :repo app env.
  use ExUnit.Case, async: false

  alias PhoenixLiveCalendar.Event
  alias PhoenixLiveCalendar.Store.Ecto.{EventSchema, EventStoreEcto}

  @schema %EventSchema{
    id: "e1",
    title: "Standup",
    start_at: ~U[2026-04-01 09:00:00Z],
    end_at: ~U[2026-04-01 09:30:00Z],
    all_day: false,
    status: "confirmed"
  }

  setup do
    prev = Application.get_env(:phoenix_live_calendar, :repo)
    Application.put_env(:phoenix_live_calendar, :repo, EventStoreEctoFakeRepo)
    Process.put(:fake_schema, @schema)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:phoenix_live_calendar, :repo, prev),
        else: Application.delete_env(:phoenix_live_calendar, :repo)
    end)

    :ok
  end

  describe "list_events/1" do
    test "maps schema rows to Event structs" do
      assert [%Event{id: "e1", title: "Standup"}] = EventStoreEcto.list_events()
    end

    test "translates range/resource/calendar/limit opts into query clauses" do
      assert [%Event{}] =
               EventStoreEcto.list_events(
                 start: ~D[2026-04-01],
                 end: ~D[2026-04-30],
                 resource_id: "r1",
                 calendar_id: "c1",
                 limit: 10
               )

      query = Process.get(:captured_query)
      # range -> 2 where clauses (start + end), resource -> 1, calendar -> 1
      assert length(query.wheres) == 4
      assert query.limit != nil
    end

    test "builds an unfiltered query when no opts are given" do
      EventStoreEcto.list_events()
      query = Process.get(:captured_query)

      assert query.wheres == []
      assert query.limit == nil
    end
  end

  describe "get_event/2" do
    test "returns an Event when found" do
      assert %Event{id: "e1"} = EventStoreEcto.get_event("e1")
    end

    test "returns nil when missing" do
      assert EventStoreEcto.get_event("missing") == nil
    end
  end

  describe "create_event/2" do
    test "inserts and returns {:ok, event}" do
      assert {:ok, %Event{title: "New"}} =
               EventStoreEcto.create_event(%{title: "New", start_at: ~U[2026-04-02 09:00:00Z]})
    end

    test "returns {:error, changeset} on invalid attrs" do
      assert {:error, %Ecto.Changeset{}} = EventStoreEcto.create_event(%{title: "No start"})
    end
  end

  describe "update_event/3" do
    test "updates and returns {:ok, event} when found" do
      assert {:ok, %Event{title: "Renamed"}} =
               EventStoreEcto.update_event("e1", %{title: "Renamed"})
    end

    test "returns {:error, :not_found} when missing" do
      assert EventStoreEcto.update_event("missing", %{title: "x"}) == {:error, :not_found}
    end
  end

  describe "delete_event/2" do
    test "returns :ok when found" do
      assert EventStoreEcto.delete_event("e1") == :ok
    end

    test "returns {:error, :not_found} when missing" do
      assert EventStoreEcto.delete_event("missing") == {:error, :not_found}
    end
  end
end
