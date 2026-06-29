if Code.ensure_loaded?(Ecto) do
  defmodule PhoenixLiveSchedule.Store.Ecto.Migrations do
    @moduledoc """
    Versioned migrations for PhoenixLiveSchedule's Ecto persistence layer.

    Follows the Oban pattern: consumers generate a migration that delegates
    to this module, allowing PhoenixLiveSchedule to manage schema changes across
    versions without consumers modifying their migrations.

    ## Usage

    Generate a migration:

        mix ecto.gen.migration add_phoenix_live_schedule

    Then edit it:

        defmodule MyApp.Repo.Migrations.AddPhoenixLiveSchedule do
          use Ecto.Migration

          def up, do: PhoenixLiveSchedule.Store.Ecto.Migrations.up(version: 1)
          def down, do: PhoenixLiveSchedule.Store.Ecto.Migrations.down(version: 1)
        end

    ## Options

    - `:version` — Target migration version (default: latest)
    - `:prefix` — PostgreSQL schema prefix for multi-tenant (default: "public")
    """

    use Ecto.Migration

    @current_version 1

    @doc "Returns the current migration version."
    def current_version, do: @current_version

    @doc """
    Runs migrations up to the specified version.
    """
    def up(opts \\ []) do
      version = Keyword.get(opts, :version, @current_version)
      prefix = Keyword.get(opts, :prefix, "public")

      if version >= 1, do: migrate_v1_up(prefix)
    end

    @doc """
    Rolls back migrations down to the specified version.
    """
    def down(opts \\ []) do
      version = Keyword.get(opts, :version, @current_version)
      prefix = Keyword.get(opts, :prefix, "public")

      if version >= 1, do: migrate_v1_down(prefix)
    end

    # -- V1: Initial schema --

    defp migrate_v1_up(prefix) do
      create_if_not_exists table(:phoenix_live_schedule_events, primary_key: false, prefix: prefix) do
        add(:id, :binary_id, primary_key: true)
        add(:title, :string)
        add(:description, :text)
        add(:location, :string)
        add(:url, :string)

        add(:start_at, :utc_datetime, null: false)
        add(:end_at, :utc_datetime)
        add(:all_day, :boolean, default: false, null: false)
        add(:start_date, :date)
        add(:end_date, :date)

        add(:color, :string)
        add(:text_color, :string)
        add(:class, :string)

        add(:group_id, :string)
        add(:resource_id, :string)
        add(:resource_ids, {:array, :string})
        add(:category, :string)

        add(:editable, :boolean, default: true, null: false)
        add(:overlap, :boolean, default: true, null: false)
        add(:display, :string, default: "auto", null: false)

        add(:status, :string, default: "confirmed", null: false)
        add(:transparency, :string, default: "opaque", null: false)
        add(:priority, :string, default: "normal", null: false)
        add(:urgency, :string, default: "none", null: false)
        add(:visibility, :integer, default: 20, null: false)

        add(:icon, :string)
        add(:badge, :string)
        add(:border_color, :string)

        add(:rrule, :string)
        add(:recurrence_id, :binary_id)

        add(:calendar_id, :string)
        add(:extra, :map, default: %{})

        timestamps(type: :utc_datetime)
      end

      # Performance indexes
      create_if_not_exists(index(:phoenix_live_schedule_events, [:start_at], prefix: prefix))

      create_if_not_exists(
        index(:phoenix_live_schedule_events, [:calendar_id, :start_at], prefix: prefix)
      )

      create_if_not_exists(
        index(:phoenix_live_schedule_events, [:resource_id, :start_at], prefix: prefix)
      )

      create_if_not_exists(
        index(:phoenix_live_schedule_events, [:calendar_id, :resource_id, :start_at],
          prefix: prefix
        )
      )

      create_if_not_exists(index(:phoenix_live_schedule_events, [:group_id], prefix: prefix))
      create_if_not_exists(index(:phoenix_live_schedule_events, [:recurrence_id], prefix: prefix))

      # Resource table
      create_if_not_exists table(:phoenix_live_schedule_resources,
                             primary_key: false,
                             prefix: prefix
                           ) do
        add(:id, :binary_id, primary_key: true)
        add(:title, :string, null: false)
        add(:parent_id, :binary_id)
        add(:color, :string)
        add(:type, :string)
        add(:order, :integer)
        add(:calendar_id, :string)
        add(:extra, :map, default: %{})

        timestamps(type: :utc_datetime)
      end

      create_if_not_exists(index(:phoenix_live_schedule_resources, [:calendar_id], prefix: prefix))
      create_if_not_exists(index(:phoenix_live_schedule_resources, [:parent_id], prefix: prefix))
    end

    defp migrate_v1_down(prefix) do
      drop_if_exists(table(:phoenix_live_schedule_resources, prefix: prefix))
      drop_if_exists(table(:phoenix_live_schedule_events, prefix: prefix))
    end
  end
end
