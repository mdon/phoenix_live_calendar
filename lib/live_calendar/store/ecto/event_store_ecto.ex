if Code.ensure_loaded?(Ecto) do
  defmodule LiveCalendar.Store.Ecto.EventStoreEcto do
    @moduledoc """
    Default Ecto implementation of `LiveCalendar.Store.EventStore`.

    Uses `LiveCalendar.Store.Ecto.EventSchema` and the configured Ecto repo.

    ## Configuration

        config :live_calendar, repo: MyApp.Repo
    """

    @behaviour LiveCalendar.Store.EventStore

    import Ecto.Query

    alias LiveCalendar.Store.Ecto.{EventSchema, RepoHelper}

    @impl true
    def list_events(opts \\ []) do
      EventSchema
      |> filter_by_range(opts)
      |> filter_by_resource(opts)
      |> filter_by_calendar(opts)
      |> maybe_limit(opts)
      |> order_by([e], asc: e.start_at)
      |> RepoHelper.all()
      |> Enum.map(&EventSchema.to_event/1)
    end

    @impl true
    def get_event(id, _opts \\ []) do
      case RepoHelper.get(EventSchema, id) do
        nil -> nil
        schema -> EventSchema.to_event(schema)
      end
    end

    @impl true
    def create_event(attrs, _opts \\ []) do
      case EventSchema.changeset(attrs) |> RepoHelper.insert() do
        {:ok, schema} -> {:ok, EventSchema.to_event(schema)}
        {:error, changeset} -> {:error, changeset}
      end
    end

    @impl true
    def update_event(id, attrs, _opts \\ []) do
      case RepoHelper.get(EventSchema, id) do
        nil ->
          {:error, :not_found}

        schema ->
          case EventSchema.changeset(schema, attrs) |> RepoHelper.update() do
            {:ok, updated} -> {:ok, EventSchema.to_event(updated)}
            {:error, changeset} -> {:error, changeset}
          end
      end
    end

    @impl true
    def delete_event(id, _opts \\ []) do
      case RepoHelper.get(EventSchema, id) do
        nil ->
          {:error, :not_found}

        schema ->
          case RepoHelper.delete(schema) do
            {:ok, _} -> :ok
            {:error, changeset} -> {:error, changeset}
          end
      end
    end

    # -- Query helpers --

    defp filter_by_range(query, opts) do
      range_start = Keyword.get(opts, :start)
      range_end = Keyword.get(opts, :end)

      query
      |> then(fn q ->
        if range_end do
          where(q, [e], e.start_at < ^to_datetime(range_end))
        else
          q
        end
      end)
      |> then(fn q ->
        if range_start do
          where(
            q,
            [e],
            (not is_nil(e.end_at) and e.end_at > ^to_datetime(range_start)) or
              (is_nil(e.end_at) and e.start_at >= ^to_datetime(range_start))
          )
        else
          q
        end
      end)
    end

    defp filter_by_resource(query, opts) do
      case Keyword.get(opts, :resource_id) do
        nil -> query
        resource_id -> where(query, [e], e.resource_id == ^to_string(resource_id))
      end
    end

    defp filter_by_calendar(query, opts) do
      case Keyword.get(opts, :calendar_id) do
        nil -> query
        calendar_id -> where(query, [e], e.calendar_id == ^to_string(calendar_id))
      end
    end

    defp maybe_limit(query, opts) do
      case Keyword.get(opts, :limit) do
        nil -> query
        limit -> limit(query, ^limit)
      end
    end

    defp to_datetime(%Date{} = d) do
      {:ok, ndt} = NaiveDateTime.new(d, ~T[00:00:00])
      DateTime.from_naive!(ndt, "Etc/UTC")
    end

    defp to_datetime(%DateTime{} = dt), do: dt
    defp to_datetime(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC")
  end
end
